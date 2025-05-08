defmodule JsonRpc.Client.WebSocket do
  @moduledoc """
  A WebSocket client for JSON-RPC 2.0.
  """

  alias JsonRpc.Client.WebSocket.Handler

  import JsonRpc.Request, only: [is_method: 1, is_params: 1]

  @type conn_info :: String.t() | WebSockex.Conn.t()
  @type name :: atom() | {:global, term()} | {:via, module(), term()}

  @default_timeout :timer.seconds(5)

  @type option :: [
          name: name(),
          debug: WebSockex.debug_opts(),
          unrecognized_frame_handler: (WebSockex.frame() -> any())
        ]

  @doc """
  Starts a new WebSocket client that handles JSON-RPC requests and responses.

  ## Options
  - name: The name of the process.
  - debug: Debugging options for WebSockex.
  - unrecognized_frame_handler: A function that handles unrecognized frames.
    This function will be called with the unrecognized frame as an argument.
  """
  @spec start_link(conn_info(), [option()]) :: {:ok, pid()} | {:error, term()}
  def start_link(conn, opts \\ []) do
    unrecognized_frame_handler = Keyword.get(opts, :unrecognized_frame_handler, fn _ -> :ok end)

    opts =
      Keyword.delete(opts, :unrecognized_frame_handler)
      |> Keyword.put(:async, true)
      |> Keyword.put(:handle_initial_conn_failure, true)

    state = %Handler.State{
      next_id: 0,
      id_to_pid: %{},
      time_before_reconnect: 100,
      unrecognized_frame_handler: unrecognized_frame_handler
    }

    WebSockex.start_link(conn, Handler, state, opts)
  end

  @doc """
  Sends a JSON-RPC call request with params and returns the response.
  """
  @spec call_with_params(
          WebSockex.client(),
          JsonRpc.Request.method(),
          JsonRpc.Request.params(),
          timeout :: integer()
        ) :: {:ok, JsonRpc.Response.t()} | {:error, :connection_closed | :timeout}
  def call_with_params(client, method, params, timeout \\ @default_timeout)
      when is_method(method) and is_params(params) and is_integer(timeout) do
    send(client, {:call_with_params, {self(), method, params}})
    receive_response(client, timeout)
  end

  @doc """
  Sends a JSON-RPC call request without params and returns the response.
  """
  @spec call_without_params(
          WebSockex.client(),
          JsonRpc.Request.method(),
          timeout :: integer()
        ) :: {:ok, JsonRpc.Response.t()} | {:error, :connection_closed | :timeout}
  def call_without_params(client, method, timeout \\ @default_timeout)
      when is_method(method) and is_integer(timeout) do
    send(client, {:call_without_params, {self(), method}})
    receive_response(client, timeout)
  end

  @spec receive_response(WebSockex.client(), timeout :: integer()) ::
          {:ok, JsonRpc.Response.t()} | {:error, :connection_closed | :timeout}
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
    send(client, {:notify_with_params, {method, params}})
    :ok
  end

  @doc """
  Sends a JSON-RPC notification request without params.
  """
  @spec notify_without_params(WebSockex.client(), JsonRpc.Request.method()) :: :ok
  def notify_without_params(client, method) when is_method(method) do
    send(client, {:notify_without_params, method})
    :ok
  end
end
