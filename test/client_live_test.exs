defmodule ClientLiveTest do

  use ExUnit.Case

  @moduletag :live

  # These tests run against a local registry with default settings

  setup do
    client = ConfluentSchemaRegistry.client()
    # client = ConfluentSchemaRegistry.client(middleware: [Tesla.Middleware.Logger],
    #   adapter: Tesla.Adapter.Hackney)

    {:ok, client: client}
  end

  test "live", %{client: client} do
    schema = "{\"type\":\"record\",\"name\":\"test\",\"fields\":[{\"name\":\"field1\",\"type\":\"string\"},{\"name\":\"field2\",\"type\":\"int\"}]}"

    assert {:ok, "BACKWARD"} == ConfluentSchemaRegistry.get_compatibility(client)

    {:ok, 21} = ConfluentSchemaRegistry.register_schema(client, "test", schema)

    {:ok, result} = ConfluentSchemaRegistry.is_registered(client, "test", schema)
    assert result["subject"] == "test"
    {:error, 404, error} = ConfluentSchemaRegistry.is_registered(client, "test2", schema)
    assert error["error_code"] == 40401

    {:ok, subjects} = ConfluentSchemaRegistry.get_subjects(client)
    assert "test" in subjects

    assert {:ok, "FULL"} == ConfluentSchemaRegistry.update_compatibility(client, "test", "FULL")

    # assert {:ok, "FULL"} == ConfluentSchemaRegistry.update_compatibility(client, "FULL")

    assert {:ok, true} == ConfluentSchemaRegistry.is_compatible(client, "test", schema) # latest
    # assert {:ok, true} == ConfluentSchemaRegistry.is_compatible(client, "test", schema, 1)

    assert {:ok, schema} == ConfluentSchemaRegistry.get_schema(client, 21)

    {:ok, versions} = ConfluentSchemaRegistry.get_versions(client, "test")
    assert length(versions) >= 1

    {:ok, result} = ConfluentSchemaRegistry.get_schema(client, "test", List.last(versions))
    assert result["schema"] == schema
    assert result["subject"] == "test"

    {:ok, result} = ConfluentSchemaRegistry.get_schema(client, "test")
    assert result["schema"] == schema
    assert result["subject"] == "test"

    assert {:ok, 21} == ConfluentSchemaRegistry.register_schema(client, "test", schema)

    # {:ok, _version} = ConfluentSchemaRegistry.delete_version(client, "test") # latest
    # assert length(versions) >= 1
  end
end
