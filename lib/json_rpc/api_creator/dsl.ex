defmodule JsonRpc.ApiCreator.Dsl do
  @moduledoc false

  @default_retries 2
  def default_retries, do: @default_retries
  @default_timeout 5_000
  def default_timeout, do: @default_timeout
  @default_retry_on_timeout? false
  def default_retry_on_timeout?, do: @default_retry_on_timeout?
  @default_time_between_retries 200
  def default_time_between_retries, do: @default_time_between_retries

  defmodule Method do
    defstruct [
      # Required
      :method_name,
      :doc,
      :response_type,
      :parsing_error_type,
      :response_parser,
      # Optional
      :retries,
      :timeout,
      :retry_on_timeout?,
      :time_between_retries,
      :args,
      :args_transformer!
    ]
  end

  @method %Spark.Dsl.Entity{
    name: :method,
    args: [:method_name],
    target: Method,
    describe: "A method that can be called via JSON-RPC",
    schema: [
      method_name: [
        type: :string,
        required: true,
        doc: "The name of the method as it will be called via JSON-RPC"
      ],
      doc: [
        type: :string,
        required: true,
        doc: "The documentation for the method"
      ],
      response_type: [
        type: :quoted,
        required: true,
        doc: "The type of the response on success"
      ],
      parsing_error_type: [
        type: :quoted,
        required: true,
        doc: "The type of the error if parsing the response fails"
      ],
      response_parser: [
        type: {:fun, 1},
        required: true,
        doc: "The function that will parse the response"
      ],
      retries: [
        type: :integer,
        default: @default_retries,
        doc: "The number of times to retry the method if it fails"
      ],
      timeout: [
        type: :integer,
        default: @default_timeout,
        doc: "The timeout for the method in milliseconds"
      ],
      retry_on_timeout?: [
        type: :boolean,
        default: @default_retry_on_timeout?,
        doc: "Whether to retry the method if it times out"
      ],
      time_between_retries: [
        type: :integer,
        default: @default_time_between_retries,
        doc: "The time to wait between retries in milliseconds"
      ],
      args: [
        type: :quoted,
        default: [],
        doc: """
        The arguments to pass to the elixir function, which will be transformed by
        `args_transformer!` into the args sent in the JSON-RPC request
        """
      ],
      args_transformer!: [
        type: :fun,
        doc: """
        A function that takes the args passed to the elixir function and transforms them into
        the args that will be sent in the JSON-RPC request
        """
      ]
    ]
  }

  @methods %Spark.Dsl.Section{
    name: :methods,
    entities: [
      @method
    ],
    describe: "Defines the methods that can be called via JSON-RPC"
  }

  use Spark.Dsl.Extension,
    sections: [@methods],
    transformers: [
      JsonRpc.ApiCreator.GenerateMethodFunctions,
      JsonRpc.ApiCreator.GenerateOptionsType,
      JsonRpc.ApiCreator.GenerateStartLinkFunction
    ]
end
