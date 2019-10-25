defmodule CacheTest do

  use ExUnit.Case

  @moduletag :live

  # Test cache

  setup do
    # {:ok, _pid} = ConfluentSchemaRegistry.Cache.start_link([dets_dir: "/tmp"])
    {:ok, _pid} = ConfluentSchemaRegistry.Cache.start_link([])

    # client = ConfluentSchemaRegistry.client(middleware: [Tesla.Middleware.Logger])
    client = ConfluentSchemaRegistry.client()

    # Tesla.Mock doesn't work because it uses a different process for the GenServer
    # mock fn
    #   %{method: :get, url: "http://localhost:8081/schemas/ids/1"} ->
    #     schema = "{\"type\":\"record\",\"name\":\"test\",\"fields\":[{\"name\":\"field1\",\"type\":\"string\"},{\"name\":\"field2\",\"type\":\"int\"}]}"
    #     json(%{"schema" => schema})
    #   %{method: :get, url: "http://localhost:8081/subjects/test/versions/latest"} ->
    #     schema = "{\"type\":\"record\",\"name\":\"test\",\"fields\":[{\"name\":\"field1\",\"type\":\"string\"},{\"name\":\"field2\",\"type\":\"int\"}]}"
    #     json(%{"id" => 1, "schema" => schema, "subject" => "test", "version" => 1})
    #   %{method: :get, url: "http://localhost:8081/subjects/test/versions/1"} ->
    #     schema = "{\"type\":\"record\",\"name\":\"test\",\"fields\":[{\"name\":\"field1\",\"type\":\"string\"},{\"name\":\"field2\",\"type\":\"int\"}]}"
    #     json(%{"id" => 1, "schema" => schema, "subject" => "test", "version" => 1})
    # end

    {:ok, client: client}
  end

  test "cache", %{client: client} do
    schema = "{\"type\":\"record\",\"name\":\"test\",\"fields\":[{\"name\":\"field1\",\"type\":\"string\"},{\"name\":\"field2\",\"type\":\"int\"}]}"

    assert {:ok, schema} == ConfluentSchemaRegistry.Cache.get_schema(client, 21)

    cache = ConfluentSchemaRegistry.Cache.dump()
    refute Enum.empty?(cache)


    key = {ConfluentSchemaRegistry, :get_schema, [client, 21]}
    assert {:infinity, :infinity, schema} == ConfluentSchemaRegistry.Cache.cache_lookup(key)

    {:ok, versions} = ConfluentSchemaRegistry.get_versions(client, "test")
    {:ok, result} = ConfluentSchemaRegistry.Cache.get_schema(client, "test", List.last(versions))
    assert result["schema"] == schema
    assert result["subject"] == "test"

    key = {ConfluentSchemaRegistry, :get_schema, [client, "test", List.last(versions)]}
    assert {:infinity, :infinity, result} == ConfluentSchemaRegistry.Cache.cache_lookup(key)


    {:ok, result} = ConfluentSchemaRegistry.Cache.get_schema(client, "test")
    assert result["schema"] == schema
    assert result["subject"] == "test"

    key = {ConfluentSchemaRegistry, :get_schema, [client, "test", "latest"]}
    {_expires, ttl, _result} = ConfluentSchemaRegistry.Cache.cache_lookup(key)
    assert ttl == 3600

    {:ok, result} = ConfluentSchemaRegistry.Cache.is_registered(client, "test", schema)
    assert result["schema"] == schema
    assert result["subject"] == "test"

  end
end

