defmodule JsonRpc.ApiCreator do
  @moduledoc """
  Defines a use macro for creating JSON-RPC APIs.

  ## Usage

  This macro helps you create JSON-RPC API modules by automatically generating functions
  that map to JSON-RPC methods. It handles the boilerplate of making RPC calls and
  parsing responses.

  ### Basic Usage

  ```elixir
  defmodule MyApi do
    use JsonRpc.ApiCreator, {
      MyApi.Worker, # The name of the worker started with JsonRpc.Client.WebSocket.start_link/2
      [
        %{
          method: "getUser",
          doc: "Fetches a user by ID",
          response_type: User.t(),
          response_parser: &User.parse/1,
          args: [id: integer()],
          args_transformer!: fn id ->
            if is_integer(id) do
              %{id: id}
            else
              raise ArgumentError, "id must be an integer"
            end
          end
        }
      ]
    }
  end
  ```

  This will generate a function `get_user/1` that:
  1. Takes a string ID as input
  2. Makes a JSON-RPC call to the "getUser" method
  3. Parses the response into a User struct

  ### Method Configuration

  Each method in the list should be a map with the following keys:

  - `method`: The JSON-RPC method name (string)
  - `doc`: Documentation for the generated function.
  - `response_type`: The type specification for the response.
  - `response_parser`: A function that parses the raw response into the desired type. Is only called
    if the RPC call is successful. If should return `{:ok, any()}` or `{:error, any()}`.
  - `args`: A keyword list of `{arg_name, type}` tuples defining the function arguments.
    This argument is optional.
  - `args_transformer!`: A function that transforms the arguments into the format expected by the
    RPC call (can also be used to validate the arguments). This argument is required only if `args`
    is provided.

  ### Debug Mode

  You can enable debug mode by using the `:debug` option:

  ```elixir
  use JsonRpc.ApiCreator, {:debug, MyClient, [...]}
  ```

  This will print the generated code to the console.

  ### Example

  ```elixir
  defmodule UserApi do
    use JsonRpc.ApiCreator, {MyClient, [
      %{
        method: "getUser",
        doc: "Fetches a user by ID",
        response_type: User.t(),
        response_parser: &User.parse/1,
        args: [id: integer()],
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

  # Usage:
  UserApi.get_user("123") # Returns {:ok, %User{}} or {:error, reason}
  UserApi.list_users()    # Returns {:ok, [{:ok, %User{}}, ...]} or {:error, reason}
  ```
  """

  defmacro __using__({:{}, _, [:debug, client, methods]}) do
    methods
    |> List.wrap()
    |> Enum.map(&generate_ast(&1, client, __CALLER__.module))
    |> print_debug_code(__CALLER__.module)
  end

  defmacro __using__({client, methods}) do
    methods
    |> List.wrap()
    |> Enum.map(&generate_ast(&1, client, __CALLER__.module))
  end

  defp generate_ast({:%{}, _, opts}, client, module) do
    %{
      method: method,
      doc: doc,
      response_type: response_type,
      response_parser: response_parser
    } = opts = Enum.into(opts, %{})

    args = Map.get(opts, :args, []) |> List.wrap()
    args_spec = Enum.map(args, fn {arg, type} -> quote do: unquote(arg) :: unquote(type) end)
    args = Enum.map(args, fn {arg, _type} -> arg end)
    args_transformer! = get_args_transformer!(args, opts, method)

    func_name = method |> to_snake_case() |> String.to_atom()
    response_type_name = String.to_atom("#{func_name}_response") |> Macro.var(module)

    quote do
      @type unquote(response_type_name) :: unquote(response_type)

      @doc unquote(doc)
      @spec unquote(func_name)(unquote_splicing(args_spec)) ::
              Result.t(unquote(response_type_name), any())
      def unquote(func_name)(unquote_splicing(args)) do
        unquote(
          generate_function_body_ast(
            args,
            client,
            method,
            response_parser,
            args_transformer!
          )
        )
      end
    end
  end

  defp get_args_transformer!(args, opts, method) do
    case args do
      [] ->
        :nop

      [_ | _] ->
        Map.get(opts, :args_transformer!) ||
          throw("Missing key :args_transformer! for method #{method}")
    end
  end

  defp generate_function_body_ast(
         [],
         client,
         method,
         response_parser,
         _args_transformer!
       ) do
    quote do
      with {:ok, response} <-
             JsonRpc.Client.WebSocket.call_without_params(unquote(client), unquote(method)),
           {:ok, result} <- response,
           do: unquote(response_parser).(result)
    end
  end

  defp generate_function_body_ast(
         args,
         client,
         method,
         response_parser,
         args_transformer!
       ) do
    quote do
      with {:ok, response} <-
             JsonRpc.Client.WebSocket.call_with_params(
               unquote(client),
               unquote(method),
               unquote(args_transformer!).(unquote_splicing(args)) |> List.wrap()
             ),
           {:ok, result} <- response,
           do: unquote(response_parser).(result)
    end
  end

  defp print_debug_code(ast, module) do
    readable_code = ast |> Macro.to_string() |> Code.format_string!() |> IO.iodata_to_binary()
    IO.puts("Generated code for module #{module} #{readable_code}")

    ast
  end

  defp to_snake_case(str) do
    str
    |> String.replace(
      # Find a lowercase letter followed by an uppercase letter
      ~r/([a-z])([A-Z])/,
      # Replace with the lowercase letter, an underscore, and the uppercase letter
      "\\1_\\2"
    )
    |> String.downcase()
  end
end
