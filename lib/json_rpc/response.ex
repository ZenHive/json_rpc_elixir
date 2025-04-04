defmodule JsonRpc.Response do
  @moduledoc """
  Defines functions for parsing JSON-RPC responses.
  """

  alias JsonRpc.RequestId
  import RequestId, only: [is_id: 1]

  @type t :: Result.t(__MODULE__.Ok.t(), __MODULE__.Error.t())

  @type non_compliant_response :: {:non_compliant_response, map()}

  @spec parse_response(raw_response :: map()) ::
          Result.t({RequestId.t(), t()}, non_compliant_response())

  def parse_response(%{"jsonrpc" => "2.0", "id" => id, "result" => result}) when is_id(id) do
    {:ok, {id, {:ok, __MODULE__.Ok.new(result)}}}
  end

  def parse_response(%{
        "jsonrpc" => "2.0",
        "id" => id,
        "error" =>
          %{
            "code" => code,
            "message" => message
          } = raw_error
      })
      when RequestId.is_id(id) and is_integer(code) and is_binary(message) do
    error = __MODULE__.Error.new(code, message, Map.get(raw_error, "data"))

    {:ok, {id, {:error, error}}}
  end

  def parse_response(raw_response) do
    {:error, {:non_compliant_response, raw_response}}
  end

  @spec parse_batch_responses(raw_responses :: list(map())) ::
          {responses :: %{RequestId.t() => t()},
           non_compliant_response_errors :: list(non_compliant_response())}
  def parse_batch_responses(raw_responses) when is_list(raw_responses) do
    Enum.reduce(raw_responses, {%{}, []}, fn raw_response,
                                             {responses, non_compliant_response_errors} ->
      case parse_response(raw_response) do
        {:ok, {id, {ok_or_error, response}}} ->
          {Map.put(responses, id, {ok_or_error, response}), non_compliant_response_errors}

        {:error, error} ->
          {responses, [error | non_compliant_response_errors]}
      end
    end)
  end
end
