defmodule JsonRpc.ApiCreatorTest do
  defmodule User do
    @type t :: any
    @type parsing_error :: any

    def parse(data), do: {:ok, data}
  end

  defmodule Debug do
    use JsonRpc.ApiCreator,
        {:debug,
         [
           %{
             method: "getUser",
             doc: "Fetches a user by ID",
             response_type: User.t(),
             parsing_error_type: User.parsing_error(),
             response_parser: &User.parse/1,
             args: [{id, integer()}],
             args_transformer!: fn id ->
               if is_integer(id) do
                 %{id: id}
               else
                 raise ArgumentError, "id must be an integer"
               end
             end
           },
           %{
             method: "listUsers",
             doc: "Lists all users",
             timeout: 2_000,
             retries: 4,
             retry_on_timeout?: true,
             time_between_retries: 400,
             response_type: [User.t()],
             parsing_error_type: User.parsing_error() | :invalid_response,
             response_parser: fn
               response when is_list(response) ->
                 Enum.reduce_while(response, {:ok, []}, fn item, {:ok, acc} ->
                   case User.parse(item) do
                     {:ok, parsed_item} -> {:cont, {:ok, [parsed_item | acc]}}
                     {:error, _} = error -> {:halt, error}
                   end
                 end)

               _ ->
                 {:error, :invalid_response}
             end
           }
         ]}
  end

  defmodule NoDebug do
    use JsonRpc.ApiCreator, [
      %{
        method: "getUser",
        doc: "Fetches a user by ID",
        response_type: User.t(),
        parsing_error_type: User.parsing_error(),
        response_parser: &User.parse/1,
        args: [{id, integer()}],
        args_transformer!: fn id ->
          if is_integer(id) do
            %{id: id}
          else
            raise ArgumentError, "id must be an integer"
          end
        end
      },
      %{
        method: "listUsers",
        doc: "Lists all users",
        timeout: 2_000,
        retries: 4,
        retry_on_timeout?: true,
        time_between_retries: 400,
        response_type: [{:ok, User.t()} | {:error, User.parsing_error()}],
        parsing_error_type: :invalid_response,
        response_parser: fn
          response when is_list(response) -> {:ok, Enum.map(response, &User.parse/1)}
          _ -> {:error, :invalid_response}
        end
      }
    ]
  end
end
