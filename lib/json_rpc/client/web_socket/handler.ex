defmodule JsonRpc.Client.WebSocket.Handler do
  @moduledoc false

  use WebSockex

  defmodule State do
    @moduledoc false

    defstruct next_id: 0,
              id_to_pid: %{},
              time_before_reconnect: 100

    @type t :: %__MODULE__{
            next_id: non_neg_integer(),
            id_to_pid: %{non_neg_integer() => pid()},
            time_before_reconnect: non_neg_integer()
          }
  end

  @impl WebSockex
  @spec handle_connect(WebSockex.Conn.t(), State.t()) :: {:ok, State.t()}
  def handle_connect(conn, state) do
    # TODO use a logger
    IO.puts("JsonRpc websocket connected to the server: #{inspect(conn)}")

    {:ok, %State{state | time_before_reconnect: 100}}
  end

  @impl WebSockex
  @spec handle_disconnect(any(), State.t()) :: {:reconnect, State.t()}
  def handle_disconnect(connection_status_map, state) do
    # TODO use a logger
    IO.puts("JsonRpc websocket disconnected from the server: #{inspect(connection_status_map)}")

    Enum.each(state.id_to_pid, fn {_id, pid} ->
      send_connection_closed_error(pid)
    end)

    parent_pid = self()

    spawn(fn ->
      Process.sleep(state.time_before_reconnect)
      send(parent_pid, :reconnect)
    end)

    clear_messages()

    state = %State{state | id_to_pid: %{}}
    state = %State{state | time_before_reconnect: min(state.time_before_reconnect * 2, 5_000)}
    {:reconnect, state}
  end

  defp clear_messages() do
    receive do
      :reconnect ->
        :ok

      {:call_with_params, {pid, _method, _params}} ->
        send_connection_closed_error(pid)
        clear_messages()

      {:call_without_params, {pid, _method}} ->
        send_connection_closed_error(pid)
        clear_messages()

      message ->
        # TODO use a logger
        IO.puts("Ignoring message: #{inspect(message)}")
        clear_messages()
    end
  end

  defp send_connection_closed_error(pid) do
    send(pid, {:json_rpc_error, :connection_closed})
  end

  @impl WebSockex
  @spec handle_frame(any(), State.t()) :: {:ok, State.t()}
  def handle_frame(frame, state) do
    # TODO use a logger
    IO.puts("Received a frame: #{inspect(frame)}")

    try do
      do_handle_frame(frame, state)
    rescue
      error ->
        # TODO use a logger
        IO.puts(
          "Error in handle_frame/2 with frame #{inspect(frame)}, state: #{inspect(state)}, error: #{inspect(error)}"
        )

        {:ok, state}
    end
  end

  defp do_handle_frame({:text, data} = frame, state) do
    case Poison.decode(data) do
      {:error, reason} ->
        # TODO use a logger
        IO.puts("Failed to decode frame #{inspect(frame)}, error: #{inspect(reason)}")
        {:ok, state}

      {:ok, data} ->
        parse_and_send_response(data, state)
    end
  end

  defp do_handle_frame(frame, state) do
    # TODO use a logger
    IO.puts("Ignored frame: #{inspect(frame)}")

    {:ok, state}
  end

  @spec parse_and_send_response(map(), State.t()) :: {:ok, State.t()}
  defp parse_and_send_response(data, state) do
    case JsonRpc.Response.parse_response(data) do
      {:error, reason} ->
        # TODO use a logger
        IO.puts("Failed to parse frame #{inspect(data)}, error: #{inspect(reason)}")
        {:ok, state}

      {:ok, {id, response}} ->
        send_response(id, response, state)
    end
  end

  @spec send_response(JsonRpc.RequestId.t(), JsonRpc.Response.t(), State.t()) ::
          {:ok, State.t()}
  defp send_response(id, response, state) do
    case Map.fetch(state.id_to_pid, id) do
      :error ->
        # TODO use a logger
        IO.puts("invalid id (#{id}) in response #{inspect(response)}")
        {:ok, state}

      {:ok, pid} ->
        # TODO use a logger
        IO.puts("Sending response with id #{id} to pid: #{inspect(pid)}")
        send(pid, {:json_rpc_frame, response})

        {:ok, %State{state | id_to_pid: Map.delete(state.id_to_pid, id)}}
    end
  end

  @impl WebSockex
  @spec handle_info(any(), State.t()) :: {:reply, any(), State.t()} | {:ok, State.t()}
  def handle_info(message, state) do
    try do
      do_handle_info(message, state)
    rescue
      error ->
        # TODO use a logger
        IO.puts(
          "Error in handle_info/2 with message #{inspect(message)}, state: #{inspect(state)}, error: #{inspect(error)}"
        )

        {:ok, state}
    end
  end

  defp do_handle_info({:timeout_request, pid}, state) do
    id_to_pid = Map.filter(state.id_to_pid, fn {_id, current_pid} -> current_pid != pid end)

    state = %State{state | id_to_pid: id_to_pid}

    {:ok, state}
  end

  defp do_handle_info({:call_with_params, {pid, method, params}}, state) do
    JsonRpc.Request.new_call_with_params(method, params, state.next_id)
    |> send_call_request_and_update_state(pid, state)
  end

  defp do_handle_info({:call_without_params, {pid, method}}, state) do
    JsonRpc.Request.new_call_without_params(method, state.next_id)
    |> send_call_request_and_update_state(pid, state)
  end

  defp do_handle_info({:notify_with_params, {method, params}}, state) do
    JsonRpc.Request.new_notify_with_params(method, params)
    |> send_notify_request(state)
  end

  defp do_handle_info({:notify_without_params, method}, state) do
    JsonRpc.Request.new_notify_without_params(method)
    |> send_notify_request(state)
  end

  defp send_call_request_and_update_state(request, pid, state) do
    # TODO use a logger
    IO.puts("Sending call request with payload: #{request}")

    state = %State{
      next_id: state.next_id + 1,
      id_to_pid: Map.put(state.id_to_pid, state.next_id, pid)
    }

    {:reply, {:text, request}, state}
  end

  defp send_notify_request(request, state) do
    # TODO use a logger
    IO.puts("Sending notify request with payload: #{request}")
    {:reply, {:text, request}, state}
  end
end
