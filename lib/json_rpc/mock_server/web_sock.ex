defmodule JsonRpc.MockServer.WebSock do
  @moduledoc false

  @behaviour WebSock

  alias JsonRpc.MockServer

  defmodule State do
    defstruct manager: MockServer.Worker
  end

  def init(query_param) do
    worker =
      Map.fetch!(query_param, "mock_server_worker")
      |> String.to_existing_atom()

    client_id =
      Map.fetch!(query_param, "client_id")
      |> String.to_integer()

    MockServer.register_client(worker, client_id, self())
    {:ok, []}
  end

  def handle_in({frame, [opcode: :text]}, state) do
    MockServer.handle_frame(state.manager, frame)
  end

  def handle_info({:send_to_client, msg}, state) do
    {:push, msg, state}
  end

  def handle_info(msg, _state) do
    raise "#{__MODULE__} received an unrecognized message: #{inspect(msg)}"
  end
end
