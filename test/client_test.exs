defmodule ClientTest do
  use ExUnit.Case

  import Tesla.Mock

  # These are the test cases from the documentation
  # https://docs.confluent.io/current/schema-registry/develop/api.html

  setup do
    client = ConfluentSchemaRegistry.client(adapter: Tesla.Mock)

    mock(fn
      %{method: :get, url: "http://localhost:8081/schemas/ids/1"} ->
        json(%{"schema" => "{\"type\": \"string\"}"})

      %{method: :get, url: "http://localhost:8081/subjects"} ->
        json(["subject1", "subject2"])

      %{method: :get, url: "http://localhost:8081/subjects/test/versions"} ->
        json([1, 2, 3, 4])

      %{method: :delete, url: "http://localhost:8081/subjects/test"} ->
        json([1, 2, 3, 4])

      %{method: :get, url: "http://localhost:8081/subjects/test/versions/1"} ->
        json(%{"name" => "test", "version" => 1, "schema" => "{\"type\": \"string\"}"})

      %{method: :get, url: "http://localhost:8081/subjects/test/versions/latest"} ->
        json(%{"name" => "test", "version" => 1, "schema" => "{\"type\": \"string\"}"})

      %{method: :get, url: "http://localhost:8081/subjects/test/versions/1/schema"} ->
        %Tesla.Env{status: 200, body: "{\"type\": \"string\"}"}

      %{method: :post, url: "http://localhost:8081/subjects/test/versions"} ->
        json(%{"id" => 1})

      %{method: :post, url: "http://localhost:8081/subjects/test"} ->
        response = %{
          "subject" => "test",
          "id" => 1,
          "version" => 3,
          "schema" => """
          {
            \"type\": \"record\",
            \"name\": \"test\",
            \"fields\":
              [
                {
                  \"type\": \"string\",
                  \"name\": \"field1\"
                },
                {
                  \"type\": \"int\",
                  \"name\": \"field2\"
                }
              ]
          }
          """
        }

        json(response)

      %{method: :delete, url: "http://localhost:8081/subjects/test/versions/1"} ->
        %Tesla.Env{status: 200, body: 1}

      %{method: :delete, url: "http://localhost:8081/subjects/test/versions/latest"} ->
        %Tesla.Env{status: 200, body: 1}

      %{method: :post, url: "http://localhost:8081/compatibility/subjects/test/versions/latest"} ->
        json(%{"is_compatible" => true})

      %{method: :post, url: "http://localhost:8081/compatibility/subjects/test/versions/1"} ->
        json(%{"is_compatible" => true})

      %{method: :put, url: "http://localhost:8081/config"} ->
        json(%{"compatibility" => "FULL"})

      %{method: :get, url: "http://localhost:8081/config"} ->
        json(%{"compatibilityLevel" => "FULL"})

      %{method: :put, url: "http://localhost:8081/config/test"} ->
        json(%{"compatibility" => "FULL"})

      %{method: :get, url: "http://localhost:8081/config/test"} ->
        json(%{"compatibilityLevel" => "FULL"})
    end)

    {:ok, client: client}
  end

  test "get_schema id", %{client: client} do
    assert {:ok, "{\"type\": \"string\"}"} == ConfluentSchemaRegistry.get_schema(client, 1)
  end

  test "get_subjects", %{client: client} do
    assert {:ok, ["subject1", "subject2"]} == ConfluentSchemaRegistry.get_subjects(client)
  end

  test "get_versions", %{client: client} do
    assert {:ok, [1, 2, 3, 4]} == ConfluentSchemaRegistry.get_versions(client, "test")
  end

  test "delete_subject", %{client: client} do
    {:ok, [1, 2, 3, 4]} = ConfluentSchemaRegistry.delete_subject(client, "test")
  end

  test "get_schema subject", %{client: client} do
    schema = %{"name" => "test", "version" => 1, "schema" => "{\"type\": \"string\"}"}
    {:ok, schema2} = ConfluentSchemaRegistry.get_schema(client, "test", 1)
    assert schema == schema2

    {:ok, schema3} = ConfluentSchemaRegistry.get_schema(client, "test")
    assert schema == schema3
  end

  test "register_schema", %{client: client} do
    {:ok, 1} = ConfluentSchemaRegistry.register_schema(client, "test", "schema")
  end

  test "is_registered", %{client: client} do
    response = %{
      "subject" => "test",
      "id" => 1,
      "version" => 3,
      "schema" => """
      {
        \"type\": \"record\",
        \"name\": \"test\",
        \"fields\":
          [
            {
              \"type\": \"string\",
              \"name\": \"field1\"
            },
            {
              \"type\": \"int\",
              \"name\": \"field2\"
            }
          ]
      }
      """
    }

    assert {:ok, response} == ConfluentSchemaRegistry.is_registered(client, "test", "schema")
  end

  test "delete_version", %{client: client} do
    # latest
    assert {:ok, 1} == ConfluentSchemaRegistry.delete_version(client, "test")
    assert {:ok, 1} == ConfluentSchemaRegistry.delete_version(client, "test", 1)
  end

  test "is_compatible", %{client: client} do
    # latest
    assert {:ok, true} == ConfluentSchemaRegistry.is_compatible(client, "test", "schema")
    assert {:ok, true} == ConfluentSchemaRegistry.is_compatible(client, "test", "schema", 1)
  end

  test "update_compatibility", %{client: client} do
    assert {:ok, "FULL"} == ConfluentSchemaRegistry.update_compatibility(client, "FULL")
  end

  test "get_compatibility", %{client: client} do
    assert {:ok, "FULL"} == ConfluentSchemaRegistry.get_compatibility(client)
  end

  test "update_compatibility subject", %{client: client} do
    assert {:ok, "FULL"} == ConfluentSchemaRegistry.update_compatibility(client, "test", "FULL")
  end

  test "get_compatibility subject", %{client: client} do
    assert {:ok, "FULL"} == ConfluentSchemaRegistry.get_compatibility(client, "test")
  end
end
