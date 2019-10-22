defmodule ConfluentSchemaRegistry.ClientCase do
  @moduledoc """
  This module defines the test case to be used by tests that require setting up
  a client.
  """

  use ExUnit.CaseTemplate

  # using do
  #   quote do
  #   end
  # end

  setup _tags do
    client = ConfluentSchemaRegistry.client()

    {:ok, client: client}
  end
end
