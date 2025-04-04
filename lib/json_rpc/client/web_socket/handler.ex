defmodule JsonRpc.Client.WebSocket.Handler do
  @moduledoc false

  use WebSockex

  defmodule State do
    @moduledoc false

    defstruct next_id: 0,
              id_to_pid: %{}

    @type t :: %__MODULE__{
            next_id: non_neg_integer(),
            id_to_pid: %{non_neg_integer() => pid()}
          }
  end

  @spec handle_disconnect(any(), State.t()) :: {:ok, State.t()}
  def handle_disconnect(_connection_status_map, state) do
    Enum.each(state.id_to_pid, fn {_id, pid} ->
      send(pid, {:json_rpc_error, :connection_closed})
    end)

    {
      :ok,
      %State{
        next_id: state.next_id,
        id_to_pid: %{}
      }
    }
  end

  @spec handle_frame(any(), State.t()) ::
          {:reply, :pong | {:pong | any()}, State.t()} | {:ok, State.t()}
  def handle_frame(message, state) do
    try do
      do_handle_frame(message, state)
    rescue
      error ->
        # TODO use a logger
        IO.puts(
          "Error in handle_frame/2 with message #{inspect(message)}, state: #{inspect(state)}, error: #{inspect(error)}"
        )

        {:ok, state}
    end
  end

  defp do_handle_frame(:ping, state) do
    {:reply, :pong, state}
  end

  defp do_handle_frame({:ping, value}, state) do
    {:reply, {:pong, value}, state}
  end

  defp do_handle_frame({_, data}, state) do
    # TODO use a logger
    IO.puts("Received a frame: #{inspect(data)}")

    case Poison.decode(data) do
      {:error, reason} ->
        # TODO use a logger
        IO.puts("Failed to decode frame #{inspect(data)}, error: #{inspect(reason)}")
        {:ok, state}

      {:ok, data} ->
        parse_and_send_response(data, state)
    end
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
        IO.puts("Sending response with id #{id} to pid: #{inspect(pid)}")
        send(pid, {:json_rpc_frame, response})

        {
          :ok,
          %State{
            state
            | id_to_pid: Map.delete(state.id_to_pid, id)
          }
        }
    end
  end

  @spec handle_cast(any(), State.t()) :: {:reply, any(), State.t()} | {:ok, State.t()}
  def handle_cast(message, state) do
    try do
      do_handle_cast(message, state)
    rescue
      error ->
        # TODO use a logger
        IO.puts(
          "Error in handle_cast/2 with message #{inspect(message)}, state: #{inspect(state)}, error: #{inspect(error)}"
        )

        {:ok, state}
    end
  end

  defp do_handle_cast({:call_with_params, {pid, method, params}}, state) do
    JsonRpc.Request.new_call_with_params(method, params, state.next_id)
    |> send_call_request_and_update_state(pid, state)
  end

  defp do_handle_cast({:call_without_params, {pid, method}}, state) do
    JsonRpc.Request.new_call_without_params(method, state.next_id)
    |> send_call_request_and_update_state(pid, state)
  end

  defp do_handle_cast({:notify_with_params, {method, params}}, state) do
    JsonRpc.Request.new_notify_with_params(method, params)
    |> send_notify_request(state)
  end

  defp do_handle_cast({:notify_without_params, method}, state) do
    JsonRpc.Request.new_notify_without_params(method)
    |> send_notify_request(state)
  end

  defp send_call_request_and_update_state(request, pid, state) do
    # TODO use a logger
    IO.puts("Sending call request with payload: #{request}")

    {
      :reply,
      {:text, request},
      %State{
        next_id: state.next_id + 1,
        id_to_pid: Map.put(state.id_to_pid, state.next_id, pid)
      }
    }
  end

  defp send_notify_request(request, state) do
    # TODO use a logger
    IO.puts("Sending notify request with payload: #{request}")
    {:reply, {:text, request}, state}
  end

  @spec handle_info(any(), State.t()) :: {:ok, State.t()}
  def handle_info({:timeout_request, pid}, state) do
    {
      :ok,
      %State{
        state
        | id_to_pid: Map.filter(state.id_to_pid, fn {_id, current_pid} -> current_pid != pid end)
      }
    }
  end
end
