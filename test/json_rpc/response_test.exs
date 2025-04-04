defmodule JsonRpc.ResponseTest do
  use ExUnit.Case, async: true
  alias JsonRpc.Response

  describe "parse_response/1" do
    test "parses a valid response with result" do
      raw_response = %{"jsonrpc" => "2.0", "id" => 42, "result" => "random_result"}

      assert Response.parse_response(raw_response) ==
               {:ok, {42, {:ok, "random_result"}}}
    end

    test "parses a valid response with error" do
      raw_response = %{
        "jsonrpc" => "2.0",
        "id" => 99,
        "error" => %{"code" => -32600, "message" => "Invalid Request"}
      }

      expected_response = %Response.Error{
        code: %Response.Error.Code{code: -32600, description: :invalid_request},
        message: "Invalid Request",
        data: nil
      }

      assert Response.parse_response(raw_response) == {:ok, {99, {:error, expected_response}}}

      raw_response = %{raw_response | "id" => 95}
      raw_response = %{raw_response | "error" => %{"code" => -32700, "message" => "Parse error"}}

      expected_response = %Response.Error{
        code: %Response.Error.Code{code: -32700, description: :parse_error},
        message: "Parse error",
        data: nil
      }

      assert Response.parse_response(raw_response) == {:ok, {95, {:error, expected_response}}}

      raw_response = %{raw_response | "error" => %{"code" => -32601, "message" => "Method not found"}}

      expected_response = %Response.Error{
        code: %Response.Error.Code{code: -32601, description: :method_not_found},
        message: "Method not found",
        data: nil
      }

      assert Response.parse_response(raw_response) == {:ok, {95, {:error, expected_response}}}

      raw_response = %{raw_response | "error" => %{"code" => -32602, "message" => "Invalid params"}}

      expected_response = %Response.Error{
        code: %Response.Error.Code{code: -32602, description: :invalid_params},
        message: "Invalid params",
        data: nil
      }

      assert Response.parse_response(raw_response) == {:ok, {95, {:error, expected_response}}}

      raw_response = %{raw_response | "error" => %{"code" => -32603, "message" => "Internal error"}}
      expected_response = %Response.Error{
        code: %Response.Error.Code{code: -32603, description: :internal_error},
        message: "Internal error",
        data: nil
      }
      assert Response.parse_response(raw_response) == {:ok, {95, {:error, expected_response}}}

      raw_response = %{raw_response | "error" => %{"code" => -32000, "message" => "Server error"}}
      expected_response = %Response.Error{
        code: %Response.Error.Code{code: -32000, description: :server_error},
        message: "Server error",
        data: nil
      }
      assert Response.parse_response(raw_response) == {:ok, {95, {:error, expected_response}}}

      raw_response = %{raw_response | "error" => %{"code" => -32099, "message" => "Server error"}}
      expected_response = %Response.Error{
        code: %Response.Error.Code{code: -32099, description: :server_error},
        message: "Server error",
        data: nil
      }
      assert Response.parse_response(raw_response) == {:ok, {95, {:error, expected_response}}}

      raw_response = %{raw_response | "error" => %{"code" => -42, "message" => "Unknown error"}}
      expected_response = %Response.Error{
        code: %Response.Error.Code{code: -42, description: :unknown_error},
        message: "Unknown error",
        data: nil
      }
      assert Response.parse_response(raw_response) == {:ok, {95, {:error, expected_response}}}

      raw_response = %{raw_response | "error" => Map.put(raw_response["error"], "data", 42)}
      expected_response = %Response.Error{expected_response | data: 42}
      assert Response.parse_response(raw_response) == {:ok, {95, {:error, expected_response}}}
    end

    test "returns error for non-compliant response" do
      raw_response = %{"jsonrpc" => "2.0", "id" => 77}

      assert Response.parse_response(raw_response) ==
               {:error, {:non_compliant_response, raw_response}}
    end
  end

  describe "parse_batch_responses/1" do
    test "parses a list of valid responses" do
      raw_responses = [
        %{"jsonrpc" => "2.0", "id" => 11, "result" => "resultA"},
        %{"jsonrpc" => "2.0", "id" => 22, "result" => "resultB"}
      ]

      expected_responses = %{
        11 => {:ok, "resultA"},
        22 => {:ok, "resultB"}
      }

      assert Response.parse_batch_responses(raw_responses) == {expected_responses, []}
    end

    test "parses a list with non-compliant responses" do
      raw_responses = [
        %{"jsonrpc" => "2.0", "id" => 33, "result" => "resultX"},
        %{"jsonrpc" => "2.0", "id" => 44}
      ]

      expected_responses = %{
        33 => {:ok, "resultX"}
      }

      assert Response.parse_batch_responses(raw_responses) ==
               {expected_responses,
                [{:non_compliant_response, %{"jsonrpc" => "2.0", "id" => 44}}]}
    end
  end
end
