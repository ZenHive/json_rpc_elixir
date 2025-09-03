defmodule JsonRpc.ApiCreator.GenerateOptionsType do
  @moduledoc false

  use Spark.Dsl.Transformer

  def transform(dsl_state) do
    quote do
      @type option ::
              {:retries, non_neg_integer()}
              | {:timeout, non_neg_integer()}
              | {:retry_on_timeout?, boolean()}
              | {:time_between_retries, non_neg_integer()}

      @type options :: [option()]
    end
    |> then(&{:ok, Spark.Dsl.Transformer.eval(dsl_state, [], &1)})
  end
end
