defmodule JsonRpc.Response.Ok do
  @moduledoc """
  Defines a type for JSON-RPC success responses.
  """

  @type t :: any()

  def new(result), do: result
end
