defmodule DummyServer do
  require Logger

  def start(port) do
    Bandit.start_link(plug: __MODULE__.Router, scheme: :http, port: port)
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

  def handle_info(_, state) do
    {:ok, state}
  end

  def init(options) do
    {:ok, options}
  end
end
