defmodule JsonRpc.RequestId do
  @moduledoc """
  Defines a type for JSON-RPC request IDs.
  """

  @type t :: integer() | String.t() | nil

  defguard is_id(id) when is_integer(id) or is_binary(id) or is_nil(id)
end
