# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [
    method: 1,
    doc: 1,
    response_type: 1,
    parsing_error_type: 1,
    response_parser: 1,
    args: 1,
    args_transformer!: 1,
    timeout: 1,
    retries: 1,
    retry_on_timeout?: 1,
    time_between_retries: 1
  ]
]
