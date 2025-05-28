defmodule JsonRpc.MockServer do
  @moduledoc """
  A mock server to make it easier to test JsonRpc clients.
  """

  alias JsonRpc.MockServer.Worker

  require Logger

  @doc """
  Starts a mock server
  """
  @spec start_link() :: Worker.t()
  def start_link() do
    # TODO use a supervisor

    {:ok, pid} = Bandit.start_link(plug: __MODULE__.Router, scheme: :http, port: 0)

    # TODO Might be able to get the link using telemetry
    port =
      pid
      |> Supervisor.which_children()
      |> List.keyfind(:listener, 0)
      |> elem(1)
      |> :sys.get_state()
      |> then(& &1.local_info)
      |> elem(1)

    mock_server_worker = Worker.mock_server_worker_name_from_port(port)

    {:ok, mock_server_worker} =
      GenServer.start_link(
        Worker,
        %Worker.State{port: port},
        name: mock_server_worker
      )

    mock_server_worker
  end

  @spec create_clients(Worker.t(), (link :: String.t() -> any()), pos_integer()) :: any()
  def create_clients(mock_server_worker, fn_to_connect, count) do
    List.duplicate(fn -> create_client(mock_server_worker, fn_to_connect) end, count)
    |> Enum.map(&Task.async/1)
    |> Enum.map(&Task.await(&1))
  end

  @spec create_client(Worker.t(), (link :: String.t() -> any())) :: any()
  def create_client(mock_server_worker, fn_to_connect) do
    {client_id, link} = GenServer.call(mock_server_worker, {:create_new_client, self()})
    client = fn_to_connect.(link)

    receive do
      {:json_rpc_mock_server, :client_has_registered} -> client
    after
      :timer.seconds(3) ->
        raise "Client with id #{client_id} has not registered to the mock server"
    end
  end

  @doc false
  def register_client(mock_server_worker, client_id, pid) do
    GenServer.cast(mock_server_worker, {:register_client, client_id, pid})
  end

  @doc false
  def handle_frame(mock_server_worker, frame) do
    GenServer.call(mock_server_worker, {:handle_frame, frame})
  end

  def expect_frame(mock_server_worker, frame) do
    GenServer.cast(mock_server_worker, {:expect_frame, frame})
  end

  def expect_frame_and_respond(mock_server_worker, frame, response) do
    GenServer.cast(mock_server_worker, {:expect_frame_and_respond, frame, response})
  end

  def send_message_to_client(mock_server_worker, msg) do
    GenServer.call(mock_server_worker, {:send_message_to_client, msg})
  end
end
