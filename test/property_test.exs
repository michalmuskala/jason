defmodule Antidote.PropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  property "string rountrip" do
    check all string <- string(:printable) do
      assert decode(encode(string)) == string
    end
  end

  property "integer roundtrip" do
    check all integer <- integer() do
      assert decode(encode(integer)) == integer
    end
  end

  property "float roundtrip" do
    check all float <- float() do
      assert decode(encode(float)) == float
    end
  end

  property "string-keyed objects roundrtip" do
    check all json <- json(string(:printable)) do
      assert decode(encode(json)) == json
    end
  end

  property "atom-keyed objects roundtrip" do
    check all json <- json(atom(:alphanumeric)) do
      assert decode(encode(json), keys: :atoms!) == json
    end
  end

  defp decode(data, opts \\ []), do: Antidote.decode!(data, opts)
  defp encode(data), do: Antidote.encode!(data)

  defp json(keys) do
    simple = one_of([integer(), float(), string(:printable), boolean(), nil])
    tree(simple, fn json ->
      one_of([list_of(json), map_of(keys, json)])
    end)
  end
end
