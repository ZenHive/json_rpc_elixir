defmodule DummyServer do
  use GenServer

  require Logger

  def start_link(port) do
    Bandit.start_link(plug: __MODULE__.Router, scheme: :http, port: port)
    |> Result.unwrap!()

    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def set_dummy_server_pid(pid) do
    GenServer.cast(__MODULE__, {:set_dummy_server_pid, pid})
  end

  def send_message_to_client(msg) do
    GenServer.cast(__MODULE__, {:send_message_to_client, msg})
  end

  @impl GenServer
  def init(_) do
    {:ok, nil}
  end

  @impl GenServer
  def handle_cast({:set_dummy_server_pid, pid}, state) do
    if state do
      raise "DummyServer pid already set"
    end

    {:noreply, pid}
  end

  def handle_cast({:send_message_to_client, msg}, pid) do
    if pid do
      send(pid, {:send_to_client, msg})
    else
      raise "DummyServer pid not set"
    end

    {:noreply, pid}
  end
end

defmodule DummyServer.Router do
  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> WebSockAdapter.upgrade(DummyServer.WebSock, [], timeout: 60_000)
    |> halt()
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end

defmodule DummyServer.WebSock do
  @behaviour WebSock

  def init(options) do
    DummyServer.set_dummy_server_pid(self())
    {:ok, options}
  end

  def handle_in({json, [opcode: :text]}, state) do
    IO.puts("DummyServer received: #{json}")

    Poison.decode!(json)
    |> handle_request(state)
  end

  defp handle_request(%{"method" => "ignore_me" <> _}, state) do
    {:ok, state}
  end

  defp handle_request(%{"method" => "response_after_timeout" <> _} = request, state) do
    Process.sleep(100)
    send_response(request, state)
  end

  defp handle_request(%{"id" => _} = request, state) do
    send_response(request, state)
  end

  defp handle_request(request, state) do
    NotificationsStorer.add_notification(request)
    {:ok, state}
  end

  defp send_response(%{"id" => id, "method" => method} = request, state) do
    response = %{
      jsonrpc: "2.0",
      id: id
    }

    response =
      case method do
        "error" <> _ ->
          Map.put(response, :error, %{
            code: 42,
            message: "cool error message",
            data: request
          })

        _ ->
          Map.put(response, :result, request)
      end

    response = Poison.encode!(response)

    {:push, {:text, response}, state}
  end

  def handle_info({:send_to_client, msg}, state) do
    {:push, msg, state}
  end

  def handle_info(_, state) do
    {:ok, state}
  end
end
