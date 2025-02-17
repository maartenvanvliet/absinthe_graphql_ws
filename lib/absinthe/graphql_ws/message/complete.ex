defmodule Absinthe.GraphqlWS.Message.Complete do
  @moduledoc """
  Indicates that the requested operation execution has completed. If the
  server dispatched the Error message relative to the original Subscribe
  message, no Complete message will be emitted.
  """

  def new(id, payload \\ %{}) do
    Jason.encode!(%{id: id, type: "complete", payload: payload})
  end
end
