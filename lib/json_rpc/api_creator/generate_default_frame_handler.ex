defmodule JsonRpc.ApiCreator.GenerateDefaultFrameHandler do
  @moduledoc false

  use Spark.Dsl.Transformer

  def transform(dsl_state) do
    quote do
      def unrecognized_frame_handler(_), do: :ok

      defoverridable unrecognized_frame_handler: 1
    end
    |> then(&{:ok, Spark.Dsl.Transformer.eval(dsl_state, [], &1)})
  end
end
