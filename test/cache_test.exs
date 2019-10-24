defmodule CacheTest do

  use ExUnit.Case

  import Tesla.Mock

  # These are the test cases from the documentation
  # https://docs.confluent.io/current/schema-registry/develop/api.html

  setup do
    {:ok, _pid} = ConfluentSchemaRegistry.Cache.start_link([])

    # client = ConfluentSchemaRegistry.client(adapter: Tesla.Mock, middleware: [Tesla.Middleware.Logger])
    client = ConfluentSchemaRegistry.client(adapter: Tesla.Mock)

    mock fn
      %{method: :get, url: "http://localhost:8081/schemas/ids/1"} ->
        schema = "{\"type\":\"record\",\"name\":\"test\",\"fields\":[{\"name\":\"field1\",\"type\":\"string\"},{\"name\":\"field2\",\"type\":\"int\"}]}"
        json(%{"schema" => schema})
      %{method: :get, url: "http://localhost:8081/subjects/test/versions/latest"} ->
        schema = "{\"type\":\"record\",\"name\":\"test\",\"fields\":[{\"name\":\"field1\",\"type\":\"string\"},{\"name\":\"field2\",\"type\":\"int\"}]}"
        json(%{"id" => 1, "schema" => schema, "subject" => "test", "version" => 1})
      %{method: :get, url: "http://localhost:8081/subjects/test/versions/1"} ->
        schema = "{\"type\":\"record\",\"name\":\"test\",\"fields\":[{\"name\":\"field1\",\"type\":\"string\"},{\"name\":\"field2\",\"type\":\"int\"}]}"
        json(%{"id" => 1, "schema" => schema, "subject" => "test", "version" => 1})
    end

    {:ok, client: client}
  end

  test "cache", %{client: client} do
    schema = "{\"type\":\"record\",\"name\":\"test\",\"fields\":[{\"name\":\"field1\",\"type\":\"string\"},{\"name\":\"field2\",\"type\":\"int\"}]}"

    cache = ConfluentSchemaRegistry.Cache.dump()
    assert length(cache) == 0


    assert {:ok, schema} == ConfluentSchemaRegistry.Cache.get_schema(client, 1)

    cache = ConfluentSchemaRegistry.Cache.dump()
    assert length(cache) == 1

    key = {ConfluentSchemaRegistry, :get_schema, [client, 1]}
    assert {:infinity, :infinity, schema} == ConfluentSchemaRegistry.Cache.cache_lookup(key)


    {:ok, result} = ConfluentSchemaRegistry.Cache.get_schema(client, "test", 1)
    assert result["schema"] == schema
    assert result["id"] == 1
    assert result["subject"] == "test"
    assert result["version"] == 1

    key = {ConfluentSchemaRegistry, :get_schema, [client, "test", 1]}
    assert {:infinity, :infinity, result} == ConfluentSchemaRegistry.Cache.cache_lookup(key)


    {:ok, result} = ConfluentSchemaRegistry.Cache.get_schema(client, "test")
    assert result["schema"] == schema
    assert result["id"] == 1
    assert result["subject"] == "test"
    assert result["version"] == 1

    key = {ConfluentSchemaRegistry, :get_schema, [client, "test", "latest"]}
    {_expires, ttl, _result} = ConfluentSchemaRegistry.Cache.cache_lookup(key)
    assert ttl == 3600
  end
end

