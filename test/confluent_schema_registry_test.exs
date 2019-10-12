defmodule ConfluentSchemaRegistryTest do
  use ExUnit.Case
  doctest ConfluentSchemaRegistry

  test "greets the world" do
    assert ConfluentSchemaRegistry.hello() == :world
  end
end
