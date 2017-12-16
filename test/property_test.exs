defmodule Antidote.PropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  property "decode is inverse of encode" do
    check all string <- string(:printable) do
      assert decode(encode(string)) == string
    end

    check all integer <- integer() do
      assert decode(encode(integer)) == integer
    end

    check all float <- float() do
      assert decode(encode(float)) == float
    end

    check all json <- json() do
      assert decode(encode(json)) == json
    end
  end

  defp decode(data), do: Antidote.decode!(data)
  defp encode(data), do: Antidote.encode!(data)

  defp json() do
    simple = one_of([integer(), float(), string(:printable), boolean(), nil])
    tree(simple, fn json ->
      one_of([list_of(json), map_of(string(:printable), json)])
    end)
  end
end
