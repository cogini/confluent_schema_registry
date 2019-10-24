defmodule ConfluentSchemaRegistry.Cache do
  @moduledoc """
  Cache results from Confluent Schema Registry lookups
  """
  @app :confluent_schema_registry

  @ttl Application.get_env(@app, :cache_ttl, 3600)
  @refresh_cycle Application.get_env(@app, :cache_refresh_cycle, 60)

  use GenServer

  require Logger

  # Public API

  @doc "Cached version of `ConfluentSchemaRegistry.get_schema/2`"
  def get_schema(client, id) when is_integer(id) do
    GenServer.call(__MODULE__, {:get_schema, client, id})
  end

  @doc "Cached version of `ConfluentSchemaRegistry.get_schema/3`"
  def get_schema(client, subject, version \\ "latest") do
    GenServer.call(__MODULE__, {:get_schema, client, subject, version})
  end

  @doc "Cached version of `ConfluentSchemaRegistry.is_registered/3`"
  def is_registered(client, subject, schema) do
    GenServer.call(__MODULE__, {:is_registered, client, subject, schema})
  end

  # GenServer callbacks

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.merge([name: __MODULE__], opts))
  end

  @impl true
  def init(args) do
    refresh_cycle = (args[:refresh_cycle] || @refresh_cycle) * 1000
    # Logger.info("Starting with refresh cycle #{refresh_cycle}")

    :ets.new(__MODULE__, [:named_table, :set, :public, {:read_concurrency, true}])

    # Use start_timer instead of :timer.send_interval/2, as it may take
    # some time to connect to the server and/or process the results
    state = %{
      refresh_cycle: refresh_cycle,
      ref: :erlang.start_timer(refresh_cycle, self(), :refresh)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:get_schema, client, id}, _from, state) do
    mfa = {m, f, a} = {ConfluentSchemaRegistry, :get_schema, [client, id]}
    result =
      case cache_lookup(mfa) do
        {_expires, _ttl, value} ->
          {:ok, value}
        _ ->
          case apply(m, f, a) do
            {:ok, value} = result ->
              cache_insert(mfa, value, :infinity)
              result
            error ->
              error
          end
      end

    {:reply, result, state}
  end

  def handle_call({:get_schema, client, subject, version}, _from, state) do
    mfa = {m, f, a} = {ConfluentSchemaRegistry, :get_schema, [client, subject, version]}
    result =
      case cache_lookup(mfa) do
        {_expires, _ttl, value} ->
          {:ok, value}
        _ ->
          case apply(m, f, a) do
            {:ok, value} = result ->
              case version do
                "latest" ->
                  cache_insert(mfa, value, @ttl)
                _ ->
                  cache_insert(mfa, value, :infinity)
              end
              result
            error ->
              error
          end
      end

    {:reply, result, state}
  end

  def handle_call({:is_registered, client, subject, schema}, _from, state) do
    mfa = {m, f, a} = {ConfluentSchemaRegistry, :is_registered, [client, subject, schema]}
    result =
      case cache_lookup(mfa) do
        {_expires, _ttl, value} ->
          {:ok, value}
        _ ->
          case apply(m, f, a) do
            {:ok, value} = result ->
              cache_insert(mfa, value, :infinity)
              result
            error ->
              error
          end
      end

    {:reply, result, state}
  end

  @impl true
  def handle_info({:timeout, _ref, :refresh}, state) do
    # Logger.debug("Refreshing cache")

    {:ok, datetime} = DateTime.now("Etc/UTC")
    now = DateTime.to_unix(datetime)

    :ets.foldl(&refresh_cache/2, now, __MODULE__)

    refresh_cycle = state[:refresh_cycle]
    {:noreply, Map.put(state, :ref, :erlang.start_timer(refresh_cycle, self(), :refresh))}
  end
  def handle_info(info, state) do
    Logger.warn("Unexpected info: #{inspect info}")
    {:noreply, state}
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
      case :ets.lookup(__MODULE__, key) do
        [{^key, value}] -> value
        [] -> nil
      end
    catch
      :error, :badarg ->
        nil
    end
  end

  @doc false
  # Insert value with default TTL
  def cache_insert(key, value) do
    cache_insert(key, value, @ttl)
  end

  @doc false
  # Insert value with specific TTL
  def cache_insert(key, value, :infinity) do
    cache_insert(key, value, :infinity, :infinity)
  end
  def cache_insert(key, value, ttl) do
    {:ok, datetime} = DateTime.now("Etc/UTC")
    now = DateTime.to_unix(datetime)
    cache_insert(key, value, ttl, now + ttl)
  end

  @doc false
  def cache_insert(key, value, ttl, expires) do
    # This may fail if clients make calls before the table is created
    try do
      :ets.insert(__MODULE__, [{key, {expires, ttl, value}}])
    catch
      :error, :badarg ->
        nil
    end
  end

  @doc false
  # Dump cache
  def dump do
    :ets.foldl(fn (entry, acc) -> [entry | acc] end, [], __MODULE__)
  end
end
