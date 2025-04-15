defmodule UnrecognizedFrameHandler do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_responses() do
    GenServer.call(__MODULE__, :get_responses)
  end

  def add_response(response) do
    GenServer.cast(__MODULE__, {:add_response, response})
  end

  def has_json_rpc_response?(method, params \\ nil) do
    UnrecognizedFrameHandler.get_responses()
    |> Enum.any?(fn
      {:text, data} ->
        case Poison.decode(data) do
          {:ok, %{"result" => result}} ->
            result["method"] == method && result["params"] == params

          _ ->
            false
        end

      _ ->
        false
    end)
  end

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_responses, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_cast({:add_response, response}, state) do
    {:noreply, [response | state]}
  end
end
