if Code.ensure_loaded?(ExUnitProperties) do
  defmodule Jason.PropertyTest do
    use ExUnit.Case, async: true
    use ExUnitProperties

    property "string roundtrip" do
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

    property "pretty roundtrip" do
      check all json <- json(string(:printable)) do
        assert decode(encode(json, pretty: true)) == json
      end
    end

    property "unicode escaping" do
      check all string <- string(:printable) do
        encoded = encode(string, escape: :unicode)
        for << <<byte>> <- encoded >> do
          assert byte < 128
        end
        assert decode(encoded) == string
      end
    end

    property "html_safe escaping" do
      check all string <- string(:printable) do
        encoded = encode(string, escape: :html_safe)
        refute encoded =~ <<0x2028::utf8>>
        refute encoded =~ <<0x2029::utf8>>
        refute encoded =~ ~r"(?<!\\)/"
        assert decode(encoded) == string
      end
    end

    property "javascript escaping" do
      check all string <- string(:printable) do
        encoded = encode(string, escape: :javascript)
        refute encoded =~ <<0x2028::utf8>>
        refute encoded =~ <<0x2029::utf8>>
        assert decode(encoded) == string
      end
    end

    defp decode(data, opts \\ []), do: Jason.decode!(data, opts)
    defp encode(data, opts \\ []), do: Jason.encode!(data, opts)

    defp json(keys) do
      simple = one_of([integer(), float(), string(:printable), boolean(), nil])
      tree(simple, fn json ->
        one_of([list_of(json), map_of(keys, json)])
      end)
    end
  end
end
