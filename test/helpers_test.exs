defmodule Antidote.HelpersTest do
  use ExUnit.Case, async: true

  import Antidote.Helpers

  describe "json_map/2" do
    test "produces same output as regular encoding" do
      assert %Antidote.Fragment{} = helper = json_map(bar: 2, baz: 3, foo: 1)
      assert Antidote.encode!(helper) == Antidote.encode!(%{bar: 2, baz: 3, foo: 1})
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
end
