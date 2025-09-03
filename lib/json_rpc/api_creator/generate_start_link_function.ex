defmodule JsonRpc.ApiCreator.GenerateStartLinkFunction do
  @moduledoc false

  use Spark.Dsl.Transformer

  def transform(dsl_state) do
    module = dsl_state.persist.module

    quote do
      @doc """
      Starts the WebSocket client with the given URL and options.

      ## Example usage:
      ```elixir
      {:ok, client} = #{unquote(module)}.start_link("ws://localhost", name: #{unquote(module)})
      ```
      """
      @spec start_link(JsonRpc.Client.WebSocket.conn_info(), [JsonRpc.Client.WebSocket.option()]) ::
              {:ok, pid()} | {:error, term()}
      def start_link(url, opts \\ []) do
        JsonRpc.Client.WebSocket.start_link(url, opts)
      end

      @doc """
      ## Example usage:
      ```elixir
      children = [{#{unquote(module)}, "ws://localhost"}]
      opts = [strategy: :one_for_one]
      Supervisor.start_link(children, opts)
      ```

      ## Example usage with options:
      ```elixir
      children = [
        {
          #{unquote(module)},
          {
            "ws://localhost",
            name: #{unquote(module)}
          }
        }
      ]

      opts = [strategy: :one_for_one]
      Supervisor.start_link(children, opts)
      ```
      """
      def child_spec({url, opts}) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [url, opts]}
        }
      end

      def child_spec(url) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [url]}
        }
      end
    end
    |> then(&{:ok, Spark.Dsl.Transformer.eval(dsl_state, [], &1)})
  end
end
