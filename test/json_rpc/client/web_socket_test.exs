defmodule JsonRpc.Client.WebSocketTest do
  use ExUnit.Case, async: true
  alias JsonRpc.Client.WebSocket

  setup_all do
    port = 4000
    {:ok, _} = NotificationsStorer.start_link()
    {:ok, _} = DummyServer.start(port)
    {:ok, _} = WebSocket.start_link("ws://localhost:#{port}", __MODULE__)
    :ok
  end

  defp get_random_params() do
    0..:rand.uniform(13)
    |> Enum.map(&(Integer.to_string(&1) <> ":" <> Integer.to_string(:rand.uniform(1000))))
  end

  defp assert_notification_exists(content) do
    Process.sleep(1_000)

    assert Enum.any?(NotificationsStorer.get_notifications(), fn elem ->
             content == elem
           end)
  end

  test "call_with_params/3 success" do
    method = "call_with_params" <> Integer.to_string(:rand.uniform(1000))
    params = get_random_params()

    assert {:ok, {:ok, response}} = WebSocket.call_with_params(__MODULE__, method, params)
    assert response["method"] == method
    assert response["params"] == params
  end

  test "call_without_params/2 success" do
    method = "call_without_params" <> Integer.to_string(:rand.uniform(1000))

    assert {:ok, {:ok, response}} = WebSocket.call_without_params(__MODULE__, method)
    assert response["method"] == method
  end

  test "call_with_params/3 error" do
    method = "error_call_with_params" <> Integer.to_string(:rand.uniform(1000))
    params = get_random_params()

    assert {:ok, {:error, response}} = WebSocket.call_with_params(__MODULE__, method, params)
    assert response.code.code == 42
    assert response.message == "cool error message"
    assert response.data["method"] == method
    assert response.data["params"] == params
  end

  test "call_without_params/2 error" do
    method = "error_call_without_params" <> Integer.to_string(:rand.uniform(1000))

    assert {:ok, {:error, response}} = WebSocket.call_without_params(__MODULE__, method)
    assert response.code.code == 42
    assert response.message == "cool error message"
    assert response.data["method"] == method
  end

  test "call_with_params/3 no response timeout" do
    method = "ignore_me_call_with_params" <> Integer.to_string(:rand.uniform(1000))
    params = get_random_params()

    assert {:error, :timeout} = WebSocket.call_with_params(__MODULE__, method, params, 0)
  end

  test "call_without_params/2 no response timeout" do
    method = "ignore_me_call_without_params" <> Integer.to_string(:rand.uniform(1000))

    assert {:error, :timeout} = WebSocket.call_without_params(__MODULE__, method, 0)
  end

  test "call_with_params/3 response sent after timeout" do
    method = "response_after_timeout_call_with_params" <> Integer.to_string(:rand.uniform(1000))
    params = get_random_params()

    assert {:error, :timeout} = WebSocket.call_with_params(__MODULE__, method, params, 0)
  end

  test "call_without_params/2 response sent after timeout" do
    method =
      "response_after_timeout_call_without_params" <> Integer.to_string(:rand.uniform(1000))

    assert {:error, :timeout} = WebSocket.call_without_params(__MODULE__, method, 0)
  end

  test "notify_with_params/2" do
    method = "notify_with_params" <> Integer.to_string(:rand.uniform(1000))
    params = get_random_params()

    assert :ok = WebSocket.notify_with_params(__MODULE__, method, params)

    assert_notification_exists(%{
      "jsonrpc" => "2.0",
      "method" => method,
      "params" => params
    })
  end

  test "notify_without_params/1" do
    method = "notify_without_params" <> Integer.to_string(:rand.uniform(1000))

    assert :ok = WebSocket.notify_without_params(__MODULE__, method)

    assert_notification_exists(%{
      "jsonrpc" => "2.0",
      "method" => method
    })
  end
end
