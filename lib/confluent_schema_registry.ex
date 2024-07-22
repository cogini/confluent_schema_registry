defmodule ConfluentSchemaRegistry do
  @moduledoc """
  Elixir client for [Confluent Schema Registry](https://docs.confluent.io/current/schema-registry/)
  [API](https://docs.confluent.io/current/schema-registry/develop/api.html).
  """

  # Argument types
  @type id :: pos_integer
  @type schema :: binary
  @type subject :: binary
  @type code :: non_neg_integer
  @type reason :: any
  @type version :: pos_integer | binary
  @type level :: binary

  @doc ~S"""
  Create client to talk to Schema Registry.

  Options are:

  * base_url: URL of schema registry (optional, default "http://localhost:8081")
  * username: username for BasicAuth (optional)
  * password: password for BasicAuth (optional)
  * adapter: Tesla adapter config
  * middleware: List of additional middleware module config (optional)

  ## Examples

      iex> client = ConfluentSchemaRegistry.client()
      %Tesla.Client{
        adapter: nil,
        fun: nil,
        post: [],
        pre: [
          {Tesla.Middleware.BaseUrl, :call, ["http://localhost:8081"]},
          {Tesla.Middleware.Headers, :call,
           [[{"content-type", "application/vnd.schemaregistry.v1+json"}]]},
          {Tesla.Middleware.JSON, :call,
           [[decode_content_types: ["application/vnd.schemaregistry.v1+json"]]]}
        ]
      }
  """
  @spec client(Keyword.t()) :: Tesla.Client.t()
  def client(opts \\ []) do
    base_url = opts[:base_url] || "http://localhost:8081"
    opts_middleware = opts[:middleware] || []
    adapter = opts[:adapter]

    middleware =
      opts_middleware ++
        [
          {Tesla.Middleware.BaseUrl, base_url},
          {Tesla.Middleware.Headers,
           [
             {"content-type", "application/vnd.schemaregistry.v1+json"},
             {"accept", "application/vnd.schemaregistry.v1+json, application/vnd.schemaregistry+json, application/json"}
           ]},
          {Tesla.Middleware.JSON,
           decode_content_types: [
             "application/vnd.schemaregistry.v1+json",
             "application/vnd.schemaregistry+json"
           ]}
        ] ++ basic_auth(opts)
  end

  # Configure Tesla.Middleware.BasicAuth
  @spec basic_auth(Keyword.t()) :: [{Tesla.Middleware.BasicAuth, map}]
  defp basic_auth(opts) do
    if opts[:username] do
      auth_opts =
        opts
        |> Keyword.take([:username, :password])
        |> Map.new()

      [{Tesla.Middleware.BasicAuth, auth_opts}]
    else
      []
    end
  end

  @doc ~S"""
  Get the schema string identified by the input ID.

  https://docs.confluent.io/current/schema-registry/develop/api.html#get--schemas-ids-int-%20id

  Returns binary schema.

  ## Examples

      iex> ConfluentSchemaRegistry.get_schema(client, 21)
      {:ok, "{\"type\":\"record\",\"name\":\"test\",\"fields\":[{\"name\":\"field1\",\"type\":\"string\"},{\"name\":\"field2\",\"type\":\"int\"}]}"}

  """
  @spec get_schema(Tesla.Client.t(), id) :: {:ok, schema} | {:error, code, reason}
  def get_schema(client, id) when is_integer(id) do
    case do_get(client, "/schemas/ids/#{id}") do
      {:ok, %{"schema" => value}} -> {:ok, value}
      {:ok, value} -> {:error, 1, "Unexpected response: " <> value}
      error -> error
    end
  end

  @doc ~S"""
  Get a list of registered subjects.

  https://docs.confluent.io/current/schema-registry/develop/api.html#get--subjects

  Returns list of subject name strings.

  ## Examples

      iex> ConfluentSchemaRegistry.get_subjects(client)
      {:ok, ["test"]}

  """
  @spec get_subjects(Tesla.Client.t()) :: {:ok, list(subject)} | {:error, code, reason}
  def get_subjects(client) do
    case do_get(client, "/subjects") do
      {:ok, _} = result -> result
      error -> error
    end
  end

  @doc ~S"""
  Get a list of versions registered under the specified subject.

  https://docs.confluent.io/current/schema-registry/develop/api.html#get--subjects-(string-%20subject)-versions

  ```
  {:ok, [1, 2, 3, 4]} = ConfluentSchemaRegistry.get_versions(client, "test")
  ```

  Returns list of integer ids.
  """
  @spec get_versions(Tesla.Client.t(), subject) :: {:ok, list(id)} | {:error, code, reason}
  def get_versions(client, subject) do
    case do_get(client, "/subjects/#{subject}/versions") do
      {:ok, _} = result -> result
      error -> error
    end
  end

  @doc ~S"""
  Deletes the specified subject and its associated compatibility level if registered.
  It is recommended to use this API only when a topic needs to be recycled or
  in development environment.

  https://docs.confluent.io/current/schema-registry/develop/api.html#delete--subjects-(string-%20subject)

  Returns list of integer ids.

  ## Examples

      iex> ConfluentSchemaRegistry.delete_subject(client, "test")
      {:ok, [1]}

  """
  @spec delete_subject(Tesla.Client.t(), subject) :: {:ok, list(id)} | {:error, code, reason}
  def delete_subject(client, subject) do
    case do_delete(client, "/subjects/#{subject}") do
      {:ok, _} = result -> result
      error -> error
    end
  end

  @doc ~S"""
  Get a specific version of the schema registered under this subject

  https://docs.confluent.io/current/schema-registry/develop/api.html#delete--subjects-(string-%20subject)

  Returns a map with the following keys:

  * subject (string) -- Name of the subject that this schema is registered under
  * id (int) -- Globally unique identifier of the schema
  * version (int) -- Version of the returned schema
  * schema (string) -- The Avro schema string

  ```
  case ConfluentSchemaRegistry.get_schema(client, "test", "latest") do
    {:ok, reg} ->
      # Already registered
      schema = reg["schema"]
      schema_id = reg["id"]
    {:error, 404, %{"error_code" => 40401}} ->
      # Subject not found
    {:error, 404, %{"error_code" => 40402}} ->
      # Version not found
    {:error, 422, reason} ->
      # Unprocessable Entity, Invalid Avro version
    {:error, code, reason} ->
      # Other error
  end
  ```

  ## Examples

      iex> ConfluentSchemaRegistry.get_schema(client, "test")
      {:ok,
       %{
         "id" => 21,
         "schema" => "{\"type\":\"record\",\"name\":\"test\",\"fields\":[{\"name\":\"field1\",\"type\":\"string\"},{\"name\":\"field2\",\"type\":\"int\"}]}",
         "subject" => "test",
         "version" => 13
       }}

      iex> ConfluentSchemaRegistry.get_schema(client, "test", 13)
      {:ok,
       %{
         "id" => 21,
         "schema" => "{\"type\":\"record\",\"name\":\"test\",\"fields\":[{\"name\":\"field1\",\"type\":\"string\"},{\"name\":\"field2\",\"type\":\"int\"}]}",
         "subject" => "test",
         "version" => 13
       }}

  """
  @spec get_schema(Tesla.Client.t(), subject, version) ::
          {:ok, map} | {:error, code, reason}
  def get_schema(client, subject, version \\ "latest") do
    case do_get(client, "/subjects/#{subject}/versions/#{version}") do
      {:ok, _} = result -> result
      error -> error
    end
  end

  # NOTE: /subjects/#{subject}/versions/#{version}/schema not implemented, as
  # it's redundant with get_schema/3

  @doc ~S"""
  Register a new schema under the specified subject. If successfully
  registered, this returns the unique identifier of this schema in the registry.

  https://docs.confluent.io/current/schema-registry/develop/api.html#post--subjects-(string-%20subject)-versions

  Returns the integer id.

  ```
  case ConfluentSchemaRegistry.register_schema(client, "test", schema) do
    {:ok, schema_id} ->
      # Already registered
    {:error, 409, reason} ->
      # Conflict -- Incompatible Avro schema
    {:error, 422, reason} ->
      # Unprocessable Entity, Invalid Avro schema
    {:error, code, reason} ->
      # Other error
  end
  ```

  ## Examples

      iex> ConfluentSchemaRegistry.register_schema(client, "test", schema)
      {:ok, 21}

  """
  @spec register_schema(Tesla.Client.t(), subject, schema) :: {:ok, id} | {:error, code, reason}
  def register_schema(client, subject, schema) do
    case do_post(client, "/subjects/#{subject}/versions", %{schema: schema}) do
      {:ok, %{"id" => value}} -> {:ok, value}
      {:ok, value} -> {:error, 1, "Unexpected response: #{inspect(value)}"}
      error -> error
    end
  end

  @doc ~S"""
  Check if a schema has already been registered under the specified subject. If
  so, this returns the schema string along with its globally unique identifier,
  its version under this subject and the subject name.

  https://docs.confluent.io/current/schema-registry/develop/api.html#post--subjects-(string-%20subject)

  Returns map with the following keys:

  * subject (string) -- Name of the subject that this schema is registered under
  * id (int) -- Globally unique identifier of the schema
  * version (int) -- Version of the returned schema
  * schema (string) -- The Avro schema string

  ```
  schema = "{\"type\":\"record\",\"name\":\"test\",\"fields\":[{\"name\":\"field1\",\"type\":\"string\"},{\"name\":\"field2\",\"type\":\"int\"}]}"
  case ConfluentSchemaRegistry.is_registered(client, "test", schema) do
    {:ok, reg} ->
      # Found
      schema = reg["schema"]
      schema_id = reg["id"]
    {:error, 404, %{"error_code" => 40401}} ->
      # Subject not found
    {:error, 404, %{"error_code" => 40403}} ->
      # Schema not found
    {:error, code, reason} ->
      # Other error
  end
  ```

  ## Examples

      iex> ConfluentSchemaRegistry.is_registered(client, "test", schema)
      {:ok,
       %{
         "id" => 21,
         "schema" => "{\"type\":\"record\",\"name\":\"test\",\"fields\":[{\"name\":\"field1\",\"type\":\"string\"},{\"name\":\"field2\",\"type\":\"int\"}]}",
         "subject" => "test",
         "version" => 1
       }}

      iex> ConfluentSchemaRegistry.is_registered(client, "test2", schema)
      {:error, 404, %{"error_code" => 40401, "message" => "Subject not found. ..."}}

  """
  @spec is_registered(Tesla.Client.t(), subject, schema) :: {:ok, map} | {:error, code, reason}
  def is_registered(client, subject, schema) do
    case do_post(client, "/subjects/#{subject}", %{schema: schema}) do
      {:ok, _} = result -> result
      error -> error
    end
  end

  @doc ~S"""
  Deletes a specific version of the schema registered under this subject. This
  only deletes the version and the schema ID remains intact making it still
  possible to decode data using the schema ID.

  https://docs.confluent.io/current/schema-registry/develop/api.html#delete--subjects-(string-%20subject)-versions-(versionId-%20version)

  ```
  {:ok, 1} = ConfluentSchemaRegistry.delete_version(client, "test") # latest
  {:ok, 1} = ConfluentSchemaRegistry.delete_version(client, "test", 1)
  ```

  Returns integer id of deleted version.
  """
  @spec delete_version(Tesla.Client.t(), subject, version) :: {:ok, id} | {:error, code, reason}
  def delete_version(client, subject, version \\ "latest") do
    case do_delete(client, "/subjects/#{subject}/versions/#{version}") do
      {:ok, value} when is_integer(value) -> {:ok, value}
      {:ok, value} -> {:error, 1, "Unexpected response: #{inspect(value)}"}
      error -> error
    end
  end

  @doc ~S"""
  Test input schema against a particular version of a subject's schema for
  compatibility. Note that the compatibility level applied for the check is the
  configured compatibility level for the subject (`get_compatibility/2`).
  If this subject's compatibility level was never changed, then the
  global compatibility level applies (`get_compatibility/1`).

  https://docs.confluent.io/current/schema-registry/develop/api.html#post--compatibility-subjects-(string-%20subject)-versions-(versionId-%20version)

  Returns boolean.

  ## Examples

      iex> ConfluentSchemaRegistry.is_compatible(client, "test", schema)
      {:ok, true}

      iex> ConfluentSchemaRegistry.is_compatible(client, "test", schema, "latest")
      {:ok, true}

      iex> ConfluentSchemaRegistry.is_compatible(client, "test", schema, 1)
      {:ok, true}

  """
  @spec is_compatible(Tesla.Client.t(), subject, schema, version) ::
          {:ok, boolean} | {:error, code, reason}
  def is_compatible(client, subject, schema, version \\ "latest") do
    case do_post(client, "/compatibility/subjects/#{subject}/versions/#{version}", %{
           schema: schema
         }) do
      {:ok, %{"is_compatible" => value}} -> {:ok, value}
      {:ok, value} -> {:error, 1, "Unexpected response: " <> value}
      error -> error
    end
  end

  @doc ~S"""
  Update global compatibility level.

  Level is a string which must be one of BACKWARD, BACKWARD_TRANSITIVE, FORWARD,
  FORWARD_TRANSITIVE, FULL, FULL_TRANSITIVE, NONE

  https://docs.confluent.io/current/schema-registry/develop/api.html#put--config

  Returns string.

  ## Examples

      iex> ConfluentSchemaRegistry.update_compatibility(client, "test", "FULL")
      {:ok, "FULL"}

  """
  @spec update_compatibility(Tesla.Client.t(), level) :: {:ok, level} | {:error, code, reason}
        when level: binary, code: non_neg_integer, reason: any
  def update_compatibility(client, level) do
    case do_put(client, "/config", %{compatibility: level}) do
      {:ok, %{"compatibility" => value}} -> {:ok, value}
      {:ok, value} -> {:error, 1, "Unexpected response: " <> value}
      error -> error
    end
  end

  @doc ~S"""
  Get global compatibility level.

  Level is a string which will be one of BACKWARD, BACKWARD_TRANSITIVE, FORWARD,
  FORWARD_TRANSITIVE, FULL, FULL_TRANSITIVE, NONE

  https://docs.confluent.io/current/schema-registry/develop/api.html#put--config

  Returns string.

  ## Examples

      iex> ConfluentSchemaRegistry.get_compatibility(client)
      {:ok, "BACKWARD"}

  """
  @spec get_compatibility(Tesla.Client.t()) :: {:ok, level} | {:error, code, reason}
        when level: binary, code: non_neg_integer, reason: any
  def get_compatibility(client) do
    case do_get(client, "/config") do
      {:ok, %{"compatibilityLevel" => value}} -> {:ok, value}
      {:ok, value} -> {:error, 1, "Unexpected response: #{inspect(value)}"}
      error -> error
    end
  end

  @doc ~S"""
  Update compatibility level for the specified subject.

  Leve is a string which must be one of BACKWARD, BACKWARD_TRANSITIVE, FORWARD,
  FORWARD_TRANSITIVE, FULL, FULL_TRANSITIVE, NONE

  https://docs.confluent.io/current/schema-registry/develop/api.html#put--config

  Returns string.

  ## Examples

      iex> ConfluentSchemaRegistry.update_compatibility(client, "test", "FULL")
      {:ok, "FULL"}

  """
  @spec update_compatibility(Tesla.Client.t(), subject, level) ::
          {:ok, level} | {:error, code, reason}
  def update_compatibility(client, subject, level) do
    case do_put(client, "/config/#{subject}", %{compatibility: level}) do
      {:ok, %{"compatibility" => value}} -> {:ok, value}
      {:ok, value} -> {:error, 1, "Unexpected response: #{inspect(value)}"}
      error -> error
    end
  end

  @doc ~S"""
  Get compatibility level for a subject.

  Level is a string which will be one of BACKWARD, BACKWARD_TRANSITIVE, FORWARD,
  FORWARD_TRANSITIVE, FULL, FULL_TRANSITIVE, NONE

  https://docs.confluent.io/current/schema-registry/develop/api.html#put--config

  Returns string.

  ## Examples

      iex> ConfluentSchemaRegistry.get_compatibility(client, "test")
      {:ok, "FULL"}

  """
  @spec get_compatibility(Tesla.Client.t(), subject) ::
          {:ok, level} | {:error, code, reason}
  def get_compatibility(client, subject) do
    case do_get(client, "/config/#{subject}") do
      {:ok, %{"compatibilityLevel" => value}} -> {:ok, value}
      {:ok, value} -> {:error, 1, "Unexpected response: " <> value}
      error -> error
    end
  end

  # Internal utility functions

  @spec do_get(Tesla.Client.t(), binary) :: {:ok, any} | {:error, code, reason}
  defp do_get(client, url) do
    tesla_response(Tesla.get(client, url))
  end

  @spec do_delete(Tesla.Client.t(), binary) :: {:ok, any} | {:error, code, reason}
  defp do_delete(client, url) do
    tesla_response(Tesla.delete(client, url))
  end

  @spec do_post(Tesla.Client.t(), binary, any) :: {:ok, any} | {:error, code, reason}
  defp do_post(client, url, data) when is_binary(data) do
    tesla_response(Tesla.post(client, url, data))
  end

  defp do_post(client, url, data) do
    case Jason.encode(data) do
      {:ok, encoded} ->
        do_post(client, url, encoded)

      {:error, reason} ->
        {:error, 0, reason}
    end
  end

  @spec do_put(Tesla.Client.t(), binary, any) :: {:ok, any} | {:error, code, reason}
  defp do_put(client, url, data) when is_binary(data) do
    tesla_response(Tesla.put(client, url, data))
  end

  defp do_put(client, url, data) do
    case Jason.encode(data) do
      {:ok, encoded} ->
        do_put(client, url, encoded)

      {:error, reason} ->
        {:error, 0, reason}
    end
  end

  defp tesla_response({:ok, %{status: 200, body: body}}), do: {:ok, body}
  defp tesla_response({:ok, %{status: status, body: body}}), do: {:error, status, body}
  defp tesla_response({:error, reason}), do: {:error, 0, reason}
end
