defprotocol Antidote.Encoder do
  @moduledoc """
  Protocol controlling how a value is encoded to JSON.

  The protocol implementation must return either iodata or
  the `Antidote.Fragment` struct.

  ## Deriving

  The protocol allows leveraging the Elixir's `@derive` feature
  to simplify protocol implementation in trivial cases. Accepted
  options are:

    * `:only` - encodes only values of specified keys.
    * `:except` - encodes all struct fields except specified keys.

  By default all keys except the `:__struct__` key are encoded.

  ## Example

  Let's assume a presence of the following struct:

      defmodule Test do
        defstruct [:foo, :bar, :baz]
      end

  If we were to call `@derive Antidote.Encoder` just before `defstruct`,
  the follwing implementation would be generated:

      defimpl Antidote.Encoder, for: Test do
        def encode(value, opts) do
          Antidote.Helpers.json_map_take(value, [:foo, :bar, :baz], opts)
        end
      end

  If we called `@derive {Antidote.Encoder, only: [:foo]}`, the following
  implementation would be genrated:

      defimpl Antidote.Encoder, for: Test do
        def encode(value, opts) do
          Antidote.Helpers.json_map_take(value, [:foo], opts)
        end
      end

  If we called `@derive {Antidote.Encoder, except: [:foo]}`, the following
  implementation would be generated:

      defimpl Antidote.Encoder, for: Test do
        def encode(value, opts) do
          Antidote.Helpers.json_map_take(value, [:bar, :baz], opts)
        end
      end
  """

  @type t :: term
  @opaque opts :: Antidote.Encode.opts()

  @spec encode(t, opts) :: iodata | Antidote.Fragment.t
  def encode(value, opts)
end

defimpl Antidote.Encoder, for: Any do
  defmacro __deriving__(module, struct, opts) do
    fields = fields_to_encode(struct, opts)
    kv = Enum.map(fields, &{&1, Macro.var(&1, __MODULE__)})
    escape = quote(do: escape)
    encode_map = quote(do: encode_map)
    encode_args = [escape, encode_map]
    kv_iodata = Antidote.Codegen.build_kv_iodata(kv, encode_args)

    quote do
      defimpl Antidote.Encoder, for: unquote(module) do
        require Antidote.Helpers

        def encode(%{unquote_splicing(kv)}, {unquote(escape), unquote(encode_map)}) do
          unquote(kv_iodata)
        end
      end
    end
  end

  def encode(value, _opts) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: value,
      description: "an explicit protocol implementation is required."
  end

  defp fields_to_encode(struct, opts) do
    cond do
      only = Keyword.get(opts, :only) ->
        only

      except = Keyword.get(opts, :except) ->
        Map.keys(struct) -- [:__struct__ | except]

      true ->
        Map.keys(struct) -- [:__struct__]
    end
  end
end

# The following implementations are formality - they are already covered
# by the main encoding mechanism in Antidote.Encode, but exist mostly for
# documentation purposes and if anybody had the idea to call the protocol directly.

defimpl Antidote.Encoder, for: Atom do
  def encode(atom, opts) do
    Antidote.Encode.encode_atom(atom, opts)
  end
end

defimpl Antidote.Encoder, for: Integer do
  def encode(integer, _opts) do
    Antidote.Encode.encode_integer(integer)
  end
end

defimpl Antidote.Encoder, for: Float do
  def encode(float, _opts) do
    Antidote.Encode.encode_float(float)
  end
end

defimpl Antidote.Encoder, for: List do
  def encode(list, opts) do
    Antidote.Encode.encode_list(list, opts)
  end
end

defimpl Antidote.Encoder, for: Map do
  def encode(map, opts) do
    Antidote.Encode.encode_map(map, opts)
  end
end

defimpl Antidote.Encoder, for: BitString do
  def encode(binary, opts) when is_binary(binary) do
    Antidote.Encode.encode_string(binary, opts)
  end

  def encode(bitstring, _opts) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: bitstring,
      description: "cannot encode a bitstring to JSON"
  end
end

defimpl Antidote.Encoder, for: [Date, Time, NaiveDateTime, DateTime] do
  def encode(value, _opts) do
    [?\", @for.to_iso8601(value), ?\"]
  end
end

defimpl Antidote.Encoder, for: Decimal do
  def encode(value, _opts) do
    # silence the xref warning
    decimal = Decimal
    [?\", decimal.to_string(value), ?\"]
  end
end

defimpl Antidote.Encoder, for: Antidote.Fragment do
  def encode(%{encode: encode}, opts) do
    encode.(opts)
  end
end
