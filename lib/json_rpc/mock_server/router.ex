defmodule JsonRpc.MockServer.Router do
  @moduledoc false

  use Plug.Router

  plug(Plug.Logger)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> WebSockAdapter.upgrade(JsonRpc.MockServer.WebSock, conn.query_params, timeout: 60_000)
    |> halt()
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end
