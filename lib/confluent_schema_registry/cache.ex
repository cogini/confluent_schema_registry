defmodule ConfluentSchemaRegistry.Cache do
  @moduledoc """
  Cache results from Confluent Schema Registry lookups.

  Programs which use Kafka may process high message volumes and run in
  parallel, one for each partition.

  The goals of the cache are:

  1. Cache the results of registry lookups for performance
  2. Periodically refresh cached values which can change without impacting
     running processes if the update fails
  3. Avoid making multiple registry lokups in parallel for the same data, e.g.
     on startup.
  4. Avoid having the schema registry be a single point of failure, so support
     caching data persistently

  The cache stores successful responses in an ETS table and (optionally) in a
  DETS table. On startup, it initializes the ETS table from the DETS table.

  A periodic job attempts to refresh the data by making the call with the same
  arguments. If it succeeds, it updates the cache.

  The cache lookup runs in the caller's process, so it can run in parallel.
  If there is a cache miss, then it calls the GenServer to update the cache.
  This has the effect of serializing requests, ensuring that only one runs
  at a time. See https://www.cogini.com/blog/avoiding-genserver-bottlenecks/

  """
  @app :confluent_schema_registry

  @dets_table @app
  @ets_table __MODULE__

  use GenServer

  require Logger

  # Public API

  @doc "Cached version of `ConfluentSchemaRegistry.get_schema/2`"
  def get_schema(client, id) when is_integer(id) do
    mfa = {ConfluentSchemaRegistry, :get_schema, [client, id]}
    lookup_apply(mfa, :infinity)
  end

  @doc "Cached version of `ConfluentSchemaRegistry.get_schema/3`"
  def get_schema(client, subject, version \\ "latest") do
    mfa = {ConfluentSchemaRegistry, :get_schema, [client, subject, version]}
    lookup_apply(mfa, version_ttl(version))
  end

  @doc "Cached version of `ConfluentSchemaRegistry.is_registered/3`"
  def is_registered(client, subject, schema) do
    mfa = {ConfluentSchemaRegistry, :is_registered, [client, subject, schema]}
    lookup_apply(mfa, :infinity)
  end

  # When version is "latest", we need to refresh the cache later
  # When version is an integer, it won't change, so we can cache it forever
  defp version_ttl("latest"), do: :latest
  defp version_ttl(version) when is_integer(version), do: :infinity

  # Look up call in cache and run apply in GenServer if it is not found

  defp lookup_apply(mfa, ttl) do
    case cache_lookup(mfa) do
      {_expires, _ttl, value} ->
        {:ok, value}
      _ ->
        GenServer.call(__MODULE__, {:cache_apply, mfa, ttl})
    end
  end

  # GenServer callbacks

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.merge([name: __MODULE__], opts))
  end

  @impl true
  def init(args) do
    refresh_cycle = (args[:refresh_cycle] || 60) * 1000
    ttl = args[:ttl] || 3600
    cache_dir = args[:cache_dir]

    # Logger.info("Starting with refresh cycle #{refresh_cycle}")

    :ets.new(@ets_table, [:named_table, :set, :public, {:read_concurrency, true}])

    load_cache(cache_dir)

    # Use start_timer instead of :timer.send_interval/2, as it may take
    # some time to connect to the server and/or process the results
    state = %{
      refresh_cycle: refresh_cycle,
      ttl: ttl,
      cache_dir: cache_dir,
      ref: :erlang.start_timer(refresh_cycle, self(), :refresh)
    }

    {:ok, state}
  end

  defp load_cache(nil), do: :ok
  defp load_cache(cache_dir) do
    path = to_charlist(Path.join(cache_dir, "#{@dets_table}.dets"))
    case :dets.open_file(@dets_table, [file: path]) do
      {:error, reason} ->
        Logger.error("Error opening DETS file #{path}: #{inspect reason}")
      {:ok, ref} ->
        Logger.debug("DETS info #{inspect ref}: #{inspect :dets.info(ref)}")
        case :dets.to_ets(ref, @ets_table) do
          {:error, reason} ->
            Logger.error("Error loading data from DETS table #{path}: #{inspect reason}")
          _ ->
            Logger.debug("Initialized ETS cache from DETS table #{path}")
        end
    end
    :ok
  end

  @impl true
  # Run call and insert value in cache if successful
  def handle_call({:cache_apply, {m, f, a} = mfa, ttl}, _from, state) do

    response =
      case cache_lookup(mfa) do # Try again, in case it was cached by a previous call
        {_expires, _ttl, value} ->
          {:ok, value}
        _ ->
          case apply(m, f, a) do
            {:ok, value} = result ->
              cache_insert(mfa, value, ttl_value(ttl, state[:ttl]))
              result
            error ->
              error
          end
      end

    {:reply, response, state}
  end

  # Get actual ttl value
  defp ttl_value(:infinity, _ttl), do: :infinity
  defp ttl_value(:latest, ttl), do: ttl

  @impl true
  def handle_info({:timeout, _ref, :refresh}, state) do
    # Logger.debug("Refreshing cache")

    {:ok, datetime} = DateTime.now("Etc/UTC")
    now = DateTime.to_unix(datetime)

    :ets.foldl(&refresh_cache/2, now, @ets_table)

    refresh_cycle = state[:refresh_cycle]
    {:noreply, Map.put(state, :ref, :erlang.start_timer(refresh_cycle, self(), :refresh))}
  end

  @impl true
  def terminate(_reason, state) do
    if state[:cache_dir] do
      case :dets.close(@dets_table) do
        {:error, message} ->
          Logger.error("Error closing DETS table #{@dets_table}: #{inspect message}")
        :ok ->
          :ok
      end
    end

    :ok
  end

  # Refresh cache
  defp refresh_cache({_key, {:infinity, _ttl, _value}}, now), do: now
  defp refresh_cache({{m, f, a} = key, {expires, ttl, value}}, now) when now >= expires do
    case apply(m, f, a) do
      {:ok, new_value} when new_value == value ->
        # Logger.debug("Up to date for #{inspect key}")
        cache_insert(key, new_value, ttl, now + ttl)
      {:ok, new_value} ->
        # Logger.debug("New value for #{inspect key}")
        cache_insert(key, new_value, ttl, now + ttl)
      _error ->
        # Logger.debug("Error calling #{inspect key}: #{inspect error}")
        nil
    end
  end

  # Internal functions, also used for testing

  @doc false
  # Look up value in cache by key
  def cache_lookup(key) do
    # This may fail if clients make calls before the table is created
    try do
      case :ets.lookup(@ets_table, key) do
        [{^key, value}] -> value
        [] -> nil
      end
    catch
      :error, :badarg ->
        nil
    end
  end

  @doc false
  # Internal, but public so that they can be used by testsThese are internal but used by tests

  # Put value in cache
  def cache_insert(key, value, :infinity) do
    cache_insert(key, value, :infinity, :infinity)
  end
  def cache_insert(key, value, ttl) when is_integer(ttl) do
    {:ok, datetime} = DateTime.now("Etc/UTC")
    now = DateTime.to_unix(datetime)
    cache_insert(key, value, ttl, now + ttl)
  end

  @doc false
  @spec cache_insert(any, any, pos_integer, pos_integer) :: :ok | nil
  def cache_insert(key, value, ttl, expires) do
    # Logger.debug("#{inspect key} = #{inspect object}")

    # This may fail if clients make calls before the table is created
    try do
      object = {expires, ttl, value}
      :ets.insert(@ets_table, {key, object})

      # DETS insert succeeds even if there is no table open :-/
      case :dets.insert(@dets_table, {key, object}) do
        :ok ->
          :ok
        {:error, reason} ->
          Logger.warn("Could not insert to DETS table #{@dets_table}: #{inspect reason}")
      end
    catch
      :error, :badarg ->
        nil
    end
  end

  @doc false
  # Dump cache
  def dump do
    :ets.foldl(fn (entry, acc) -> [entry | acc] end, [], @ets_table)
  end
end
