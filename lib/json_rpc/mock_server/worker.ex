defmodule JsonRpc.MockServer.Worker do
  @moduledoc false

  use GenServer

  @type t :: pid() | GenServer.name()

  defmodule State do
    @enforce_keys [:port]
    defstruct port: :enforced,
              clients: %{},
              next_client_id: 0

    @type client_status ::
            {:registered, client_handler :: pid()}
            | {:unregistered, process_to_notify_on_registration :: pid()}
    @type client_id :: non_neg_integer()

    @type t :: %__MODULE__{
            port: pos_integer(),
            clients: %{(id :: client_id()) => client_status()},
            next_client_id: client_id()
          }
  end

  def mock_server_worker_name_from_port(port) when is_integer(port),
    do: :"#{__MODULE__}:port#{port}"

  @impl GenServer
  @doc false
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  @doc false
  def handle_cast({:register_client, client_id, pid}, state) do
    clients =
      Map.get_and_update(state.clients, client_id, fn
        {:unregistered, client_creator_pid} ->
          send(client_creator_pid, {:json_rpc_mock_server, :client_has_registered})
          {:registered, pid}

        nil ->
          raise "Client with id #{client_id} does not exist"

        _ ->
          raise "Client with id #{client_id} is already registered"
      end)

    {:noreply, %State{state | clients: clients}}
  end

  def handle_cast({:expect_frame, _frame}, _state) do
  end

  def handle_cast({:expect_frame_and_respond, _frame, _response}, _state) do
  end

  def handle_cast(msg, _state) do
    raise ArgumentError, "#{__MODULE__} received an invalid cast msg: #{msg}"
  end

  @impl GenServer
  @doc false
  def handle_call({:send_message_to_client, msg, dst}, _, state) do
    nb_of_msg_sent =
      Enum.reduce(state.clients, 0, fn client, acc ->
        if dst == :all || dst == client do
          send(client, {:send_to_client, msg})
          acc + 1
        else
          acc
        end
      end)

    {:reply, nb_of_msg_sent, state}
  end

  def handle_call({:create_new_client, pid}, state) do
    client_id = state.next_client_id
    state = %State{state | next_client_id: state.next_client_id + 1}
    state = %State{state | clients: Map.put(state.clients, client_id, {:unregistered, pid})}

    query_params = %{
      "mock_server_worker" => mock_server_worker_name_from_port(state.port),
      "client_id" => client_id
    }

    link = "ws://localhost:#{state.port}?#{URI.encode_query(query_params)}"

    {:reply, link, state}
  end

  def handle_call({:handle_frame, _frame}, _state) do
    raise "TODO implement this handle_frame call msg"
  end

  def handle_call(msg, _state) do
    raise ArgumentError, "#{__MODULE__} received an invalid call msg: #{msg}"
  end
end
