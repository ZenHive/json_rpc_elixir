defmodule JsonRpc.RequestIdTest do
  use ExUnit.Case, async: true
  alias JsonRpc.RequestId

  require RequestId

  describe "is_id/1" do
    test "returns true for integer ids" do
      assert RequestId.is_id(123)
    end

    test "returns true for string ids" do
      assert RequestId.is_id("abc")
    end

    test "returns true for nil ids" do
      assert RequestId.is_id(nil)
    end

    test "returns false for other types" do
      refute RequestId.is_id(123.45)
      refute RequestId.is_id(:atom)
      refute RequestId.is_id(%{})
      refute RequestId.is_id([])
    end
  end
end
