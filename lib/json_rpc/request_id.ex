defmodule JsonRpc.RequestId do
  @moduledoc """
  Defines a type for JSON-RPC request IDs.
  """

  @type t :: Option.t(integer() | String.t())

  defguard is_id(id) when is_integer(id) or is_binary(id) or is_nil(id)
end
