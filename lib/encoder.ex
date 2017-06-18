defprotocol Antidote.Encoder do
  @type t :: term
  @type opts :: %{escape: Antidote.escape, validate: Antidote.validate,
                  maps: Antidote.maps}

  @spec encode(t, opts) :: iodata
  def encode(value, opts)
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
    [?\", Decimal.to_string(value), ?\"]
  end
end

defimpl Antidote.Encoder, for: Antidote.Fragment do
  def encode(%{iodata: iodata}, _opts) do
    iodata
  end
end
