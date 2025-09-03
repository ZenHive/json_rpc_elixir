defmodule JsonRpc.ApiCreator.GenerateMethodFunctions do
  @moduledoc false

  use Spark.Dsl.Transformer

  alias JsonRpc.ApiCreator.Dsl.Method

  def transform(dsl_state) do
    function_ast =
      Spark.Dsl.Transformer.get_entities(dsl_state, [:methods])
      |> Enum.map(&generate_function_ast(&1, dsl_state.persist.module))

    quote do
      (unquote_splicing(function_ast))
    end
    |> then(&{:ok, Spark.Dsl.Transformer.eval(dsl_state, [], &1)})
  end

  defp generate_function_ast(
         %Method{
           method_name: method_name,
           doc: doc,
           response_type: response_type,
           parsing_error_type: parsing_error_type,
           response_parser: response_parser,
           retries: retries,
           timeout: timeout,
           retry_on_timeout?: retry_on_timeout?,
           time_between_retries: time_between_retries,
           args: args,
           args_transformer!: args_transformer!
         },
         module
       ) do
    args = List.wrap(args)

    args_spec = Enum.map(args, fn {arg, type} -> quote do: unquote(arg) :: unquote(type) end)

    args =
      Enum.map(args, fn {arg, _type} ->
        case arg do
          {arg_name, _, _} when is_atom(arg_name) ->
            if Atom.to_string(arg_name) |> String.starts_with?("__") do
              raise "Argument name #{arg_name} cannot start with '__'. This is reserved for " <>
                      "internal use."
            end

          _ ->
            raise "Argument #{inspect(arg)} must be a tuple of the form {arg_name, type}. " <>
                    "We do not support pattern matching in argument names at the moment."
        end

        arg
      end)

    args_transformer! = get_args_transformer!(args, args_transformer!, method_name)

    func_name = method_name |> to_snake_case() |> String.to_atom()
    error_type_name = :"#{func_name}_error" |> Macro.var(module)
    do_func_name = :"__do_#{func_name}"

    quote do
      @doc unquote(doc)
      @type unquote(error_type_name) ::
              :connection_closed
              | :timeout
              | JsonRpc.Response.Error.t()
              | {:parsing_error, unquote(parsing_error_type)}
      @spec unquote(func_name)(WebSockex.client(), unquote_splicing(args_spec), options()) ::
              {:ok, unquote(response_type)} | {:error, unquote(error_type_name)}
      def unquote(func_name)(__client, unquote_splicing(args), __opts \\ []) do
        unquote(do_func_name)(
          __client,
          unquote_splicing(args),
          Keyword.get(__opts, :timeout, unquote(timeout)),
          Keyword.get(__opts, :retries, unquote(retries)),
          Keyword.get(__opts, :retry_on_timeout?, unquote(retry_on_timeout?)),
          Keyword.get(__opts, :time_between_retries, unquote(time_between_retries))
        )
      end

      defp unquote(do_func_name)(
             __client,
             unquote_splicing(args),
             __timeout,
             __retries,
             __retry_on_timeout?,
             __time_between_retries
           ) do
        __result =
          unquote(
            if args != [] do
              quote do
                JsonRpc.Client.WebSocket.call_with_params(
                  __client,
                  unquote(method_name),
                  unquote(args_transformer!).(unquote_splicing(args)) |> List.wrap(),
                  __timeout
                )
              end
            else
              quote do
                JsonRpc.Client.WebSocket.call_without_params(
                  __client,
                  unquote(method_name),
                  __timeout
                )
              end
            end
          )

        case __result do
          {:ok, __raw_response_result} ->
            # This pattern is only valid if the response is neither :connection_closed nor :timeout
            with {:ok, __raw_response} <- __raw_response_result,
                 {:error, __reason} <- unquote(response_parser).(__raw_response),
                 do: {:error, {:parsing_error, __reason}}

          {:error, __reason} ->
            if __retries > 0 && (__reason != :timeout || __retry_on_timeout?) do
              Process.sleep(__time_between_retries)

              unquote(do_func_name)(
                __client,
                unquote_splicing(args),
                __timeout,
                __retries - 1,
                __retry_on_timeout?,
                __time_between_retries
              )
            else
              {:error, __reason}
            end
        end
      end
    end
  end

  defp get_args_transformer!(args, args_transformer!, method_name) do
    if args != [] && args_transformer! == nil do
      throw("Missing key :args_transformer! for method #{method_name}")
    end

    args_transformer! || :nop
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
