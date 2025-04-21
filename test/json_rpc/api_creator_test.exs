defmodule JsonRpc.ApiCreatorTest do
  defmodule User do
    @type t :: any

    def parse(data), do: data
  end

  defmodule Debug do
    use JsonRpc.ApiCreator,
        {:debug,
         [
           %{
             method: "getUser",
             doc: "Fetches a user by ID",
             response_type: User.t(),
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
             response_type: [User.t()],
             response_parser: fn
               response when is_list(response) -> {:ok, Enum.map(response, &User.parse/1)}
               _ -> {:error, "Invalid response"}
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
        response_type: [User.t()],
        response_parser: fn
          response when is_list(response) -> {:ok, Enum.map(response, &User.parse/1)}
          _ -> {:error, "Invalid response"}
        end
      }
    ]
  end
end
