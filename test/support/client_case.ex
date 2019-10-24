defmodule ConfluentSchemaRegistry.ClientCase do
  @moduledoc """
  This module defines the test case to be used by tests that require setting up
  a client.
  """

  use ExUnit.CaseTemplate

  setup _tags do
    client = ConfluentSchemaRegistry.client(adapter: Tesla.Mock)
    {:ok, client: client}
  end
end
