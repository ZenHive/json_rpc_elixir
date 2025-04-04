defmodule JsonRpc.Client.WebSocket do
  alias JsonRpc.Client.WebSocket.Handler

  import JsonRpc.Request, only: [is_method: 1, is_params: 1]

  @type conn_info :: String.t() | WebSockex.Conn.t()

  @default_timeout :timer.seconds(5)

  @doc """
  Starts a new WebSocket client that handles JSON-RPC requests and responses.
  """
  @spec start_link(conn_info(), WebSockex.options()) :: Result.t(pid(), term())
  def start_link(conn, opts \\ []) do
    WebSockex.start_link(conn, Handler, %Handler.State{}, opts)
  end

  @doc """
  Sends a JSON-RPC call request with params and returns the response.
  """
  @spec call_with_params(
          WebSockex.client(),
          JsonRpc.Request.method(),
          JsonRpc.Request.params(),
          timeout :: integer()
        ) :: Result.t(JsonRpc.Response.t(), term())
  def call_with_params(client, method, params, timeout \\ @default_timeout)
      when is_method(method) and is_params(params) and is_integer(timeout) do
    WebSockex.cast(client, {:call_with_params, {self(), method, params}})
    receive_response(client, timeout)
  end

  @doc """
  Sends a JSON-RPC call request without params and returns the response.
  """
  @spec call_without_params(
          WebSockex.client(),
          JsonRpc.Request.method(),
          timeout :: integer()
        ) :: Result.t(JsonRpc.Response.t(), term())
  def call_without_params(client, method, timeout \\ @default_timeout)
      when is_method(method) and is_integer(timeout) do
    WebSockex.cast(client, {:call_without_params, {self(), method}})
    receive_response(client, timeout)
  end

  @spec receive_response(WebSockex.client(), timeout :: integer()) ::
          Result.t(JsonRpc.Response.t(), term())
  defp receive_response(client, timeout) do
    receive do
      {:json_rpc_frame, response} -> {:ok, response}
      {:json_rpc_error, reason} -> {:error, reason}
    after
      timeout ->
        send(client, {:timeout_request, self()})

        # In case the response was sent as we were telling it to time it out
        receive do
          {:json_rpc_frame, response} -> {:ok, response}
          {:json_rpc_error, reason} -> {:error, reason}
        after
          0 -> {:error, :timeout}
        end
    end
  end

  @doc """
  Sends a JSON-RPC notification request with params.
  """
  @spec notify_with_params(WebSockex.client(), JsonRpc.Request.method(), JsonRpc.Request.params()) ::
          :ok
  def notify_with_params(client, method, params) when is_method(method) and is_params(params) do
    WebSockex.cast(client, {:notify_with_params, {method, params}})
  end

  @doc """
  Sends a JSON-RPC notification request without params.
  """
  @spec notify_without_params(WebSockex.client(), JsonRpc.Request.method()) :: :ok
  def notify_without_params(client, method) when is_method(method) do
    WebSockex.cast(client, {:notify_without_params, method})
  end
end
