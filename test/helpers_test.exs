defmodule Antidote.HelpersTest do
  use ExUnit.Case, async: true

  import Antidote.Helpers

  describe "json_map/2" do
    test "produces same output as regular encoding" do
      assert %Antidote.Fragment{} = helper = json_map(bar: 2, baz: 3, foo: 1)
      assert Antidote.encode!(helper) == Antidote.encode!(%{bar: 2, baz: 3, foo: 1})
    end

    test "rejects keys with invalid characters" do
      assert_eval_raise Antidote.EncodeError, """
      json_map("/foo": 1)
      """

      assert_eval_raise Antidote.EncodeError, ~S"""
      json_map("\\foo": 1)
      """

      assert_eval_raise Antidote.EncodeError, ~S"""
      json_map("\"foo": 1)
      """
    end
  end

  describe "json_map_take/3" do
    test "is hygienic" do
      map = %{escape: 1}
      assert %Antidote.Fragment{} = helper = json_map_take(map, [:escape])
      assert Keyword.keys(binding()) == [:helper, :map]
      assert Antidote.encode!(helper) == Antidote.encode!(map)
    end

    test "fails gracefully" do
      assert_raise ArgumentError, fn ->
        json_map_take(%{foo: 1}, [:bar])
      end

      assert_raise ArgumentError, fn ->
        json_map_take(1, [:bar])
      end
    end
  end

  defp assert_eval_raise(error, string) do
    assert_raise error, fn ->
      Code.eval_string(string, [], __ENV__)
    end
  end
end
