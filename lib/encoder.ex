defmodule Antidote.EncodeError do
  defexception [:message]

  def exception({:duplicate_key, key}) do
    %__MODULE__{message: "duplicate key: #{key}"}
  end
  def exception({:invalid_byte, byte, original}) do
    %__MODULE__{message: "invalid byte #{inspect byte, base: :hex} in #{inspect original}"}
  end
end

defmodule Antidote.Encode do
  @type escape :: :json | :unicode | :html | :javascript
  @type validate :: boolean
  @type maps :: :naive | :strict

  alias Antidote.{Codegen, EncodeError}

  # @compile :native

  def encode(value, opts) do
    escape = escape_function(opts)
    encode_map = encode_map_function(opts)
    try do
      {:ok, encode_dispatch(value, escape, encode_map, opts)}
    catch
      {:duplicate_key, _} = err ->
        {:error, EncodeError.exception(err)}
      {:invalid_byte, _, _} = err ->
        {:error, EncodeError.exception(err)}
    end
  end

  defp encode_map_function(%{maps: maps}) do
    case maps do
      :naive -> &encode_map_naive/4
      :strict -> &encode_map_strict/4
    end
  end

  defp escape_function(%{escape: escape, validate: validate}) do
    case {escape, validate} do
      {:json, true} -> &escape_json_strict/4
      {:json, false} -> &escape_json_naive/4
      # {:unicode, _} -> &escape_unicode/3
      # {:html, true} -> &escape_html_validate/3
      # {:html, false} -> &escape_html_naive/3
      # {:javascript, true} -> &escape_javascript_validate/3
      # {:javascript, false} -> &escape_javascript_naive/3
      _ -> fn _,_,_,_ -> raise "not supported" end
    end
  end

  defp encode_dispatch(value, escape, _encode_map, _opts) when is_atom(value) do
    do_encode_atom(value, escape)
  end

  defp encode_dispatch(value, escape, _encode_map, _opts) when is_binary(value) do
    do_encode_string(value, escape)
  end

  defp encode_dispatch(value, _escape, _encode_map, _opts) when is_integer(value) do
    encode_integer(value)
  end

  defp encode_dispatch(value, _escape, _encode_map, _opts) when is_float(value) do
    encode_float(value)
  end

  defp encode_dispatch(value, escape, encode_map, opts) when is_list(value) do
    encode_list(value, escape, encode_map, opts)
  end

  defp encode_dispatch(%{__struct__: module} = value, _escape, _encode_map, opts) do
    encode_struct(value, opts, module)
  end

  defp encode_dispatch(value, escape, encode_map, opts) when is_map(value) do
    encode_map.(value, escape, encode_map, opts)
  end

  defp encode_dispatch(value, _escape, _encode_map, opts) do
    Antidote.Encoder.encode(value, opts)
  end

  # @compile {:inline,
  #           do_encode_atom: 2, do_encode_string: 2, encode_integer: 1,
  #           encode_float: 1, encode_list: 4, encode_struct: 3}
  @compile {:inline, encode_integer: 1, encode_float: 1}

  def encode_atom(atom, opts) do
    escape = escape_function(opts)
    do_encode_atom(atom, escape)
  end

  defp do_encode_atom(nil, _escape), do: "null"
  defp do_encode_atom(true, _escape), do: "true"
  defp do_encode_atom(false, _escape), do: "false"
  defp do_encode_atom(atom, escape),
    do: do_encode_string(Atom.to_string(atom), escape)

  def encode_integer(integer) do
    Integer.to_string(integer)
  end

  def encode_float(float) do
    :io_lib_format.fwrite_g(float)
  end

  def encode_list(list, opts) do
    escape = escape_function(opts)
    encode_map = encode_map_function(opts)
    encode_list(list, escape, encode_map, opts)
  end

  defp encode_list([], _escape, _encode_map, _opts) do
    "[]"
  end

  defp encode_list([head | tail], escape, encode_map, opts) do
    '[' ++ [encode_dispatch(head, escape, encode_map, opts)
     | encode_list_loop(tail, escape, encode_map, opts)]
  end

  defp encode_list_loop([], _escape, _encode_map, _opts) do
    ']'
  end

  defp encode_list_loop([head | tail], escape, encode_map, opts) do
    [?,, encode_dispatch(head, escape, encode_map, opts)
     | encode_list_loop(tail, escape, encode_map, opts)]
  end

  def encode_map(value, opts) do
    escape = escape_function(opts)
    encode_map = encode_map_function(opts)
    encode_map.(value, escape, encode_map, opts)
  end

  defp encode_map_naive(value, escape, encode_map, opts) do
    case Map.to_list(value) do
      [] -> "{}"
      [{key, value} | tail] ->
        ["{\"", encode_key(key, escape), "\":",
         encode_dispatch(value, escape, encode_map, opts)
         | encode_map_naive_loop(tail, escape, encode_map, opts)]
    end
  end

  defp encode_map_naive_loop([], _escape, _encode_map, _opts) do
    '}'
  end

  defp encode_map_naive_loop([{key, value} | tail], escape, encode_map, opts) do
    [",\"", encode_key(key, escape), "\":",
     encode_dispatch(value, escape, encode_map, opts)
     | encode_map_naive_loop(tail, escape, encode_map, opts)]
  end

  defp encode_map_strict(value, escape, encode_map, opts) do
    case Map.to_list(value) do
      [] -> "{}"
      [{key, value} | tail] ->
        key = IO.iodata_to_binary(encode_key(key, escape))
        visited = %{key => []}
        ["{\"", key, "\":",
         encode_dispatch(value, escape, encode_map, opts)
         | encode_map_strict_loop(tail, escape, encode_map, opts, visited)]
    end
  end

  defp encode_map_strict_loop([], _encode_map, _escape, _opts, _visited) do
    '}'
  end

  defp encode_map_strict_loop([{key, value} | tail], escape, encode_map, opts, visited) do
    key = IO.iodata_to_binary(encode_key(key, escape))
    case visited do
      %{^key => _} ->
        throw {:duplicate_key, key}
      _ ->
        visited = Map.put(visited, key, [])
        [",\"", key, "\":",
         encode_dispatch(value, escape, encode_map, opts)
         | encode_map_strict_loop(tail, escape, encode_map, opts, visited)]
    end
  end

  for module <- [Date, Time, NaiveDateTime, DateTime] do
    defp encode_struct(value, _opts, unquote(module)) do
      [?\", unquote(module).to_iso8601(value), ?\"]
    end
  end

  defp encode_struct(value, _opts, Decimal) do
    [?\", Decimal.to_string(value, :normal), ?\"]
  end

  defp encode_struct(value, _opts, Antidote.Fragment) do
    Map.fetch!(value, :iodata)
  end

  defp encode_struct(value, opts, _module) do
    Antidote.Encoder.encode(value, opts)
  end

  # Should we allow more things as keys?
  defp encode_key(atom, escape) when is_atom(atom) do
    string = Atom.to_string(atom)
    escape.(string, string, 0, :noclose)
  end
  defp encode_key(string, escape) when is_binary(string) do
    escape.(string, string, 0, :noclose)
  end
  defp encode_key(integer, _escape) when is_integer(integer) do
    Integer.to_string(integer)
  end

  def encode_string(string, opts) do
    escape = escape_function(opts)
    do_encode_string(string, escape)
  end

  defp do_encode_string(string, escape) do
    [?\" | escape.(string, string, 0, :close)]
  end

  slash_escapes = Enum.zip('\b\t\n\f\r\"\\', 'btnfr"\\')
  ranges = [{0x00..0x1F, :unicode} | slash_escapes]
  escape_jt = Codegen.jump_table(ranges, :error)

  Enum.map(escape_jt, fn
    {byte, :unicode} ->
      sequence = List.to_string(:io_lib.format("\\u~4.16.0B", [byte]))
      defp escape(unquote(byte)), do: unquote(sequence)
    {byte, :error} ->
      defp escape(unquote(byte)), do: :erlang.error(:badarg)
    {byte, char} when is_integer(char) ->
      defp escape(unquote(byte)), do: unquote(<<?\\, char>>)
  end)

  ## JSON naive escape

  json_naive_jt = Codegen.jump_table(ranges, :chunk, 0x5C + 1)

  defp escape_json_naive(data, original, skip, close) do
    escape_json_naive(data, [], original, skip, close)
  end

  Enum.map(json_naive_jt, fn
    {byte, :chunk} ->
      defp escape_json_naive(<<byte, rest::bits>>, acc, original, skip, close)
           when byte === unquote(byte) do
        escape_json_naive_chunk(rest, acc, original, skip, close, 1)
      end
    {byte, _escape} ->
      defp escape_json_naive(<<byte, rest::bits>>, acc, original, skip, close)
           when byte === unquote(byte) do
        acc = [acc | escape(byte)]
        escape_json_naive(rest, acc, original, skip + 1, close)
      end
  end)
  defp escape_json_naive(<<_byte, rest::bits>>, acc, original, skip, close) do
    escape_json_naive_chunk(rest, acc, original, skip, close, 1)
  end
  defp escape_json_naive(<<>>, acc, _original, _skip, :close) do
    [acc, ?\"]
  end
  defp escape_json_naive(<<>>, acc, _original, _skip, :noclose) do
    acc
  end

  Enum.map(json_naive_jt, fn
    {byte, :chunk} ->
      defp escape_json_naive_chunk(<<byte, rest::bits>>, acc, original, skip, close, len)
           when byte === unquote(byte) do
        escape_json_naive_chunk(rest, acc, original, skip, close, len + 1)
      end
    {byte, _escape} ->
      defp escape_json_naive_chunk(<<byte, rest::bits>>, acc, original, skip, close, len)
           when byte === unquote(byte) do
        part = binary_part(original, skip, len)
        acc = [acc, part | escape(byte)]
        escape_json_naive(rest, acc, original, skip + len + 1, close)
      end
  end)
  defp escape_json_naive_chunk(<<_byte, rest::bits>>, acc, original, skip, close, len) do
    escape_json_naive_chunk(rest, acc, original, skip, close, len + 1)
  end
  defp escape_json_naive_chunk(<<>>, acc, original, skip, :close, len) do
    part = binary_part(original, skip, len)
    [acc, part, ?\"]
  end
  defp escape_json_naive_chunk(<<>>, acc, original, skip, :noclose, len) do
    [acc | binary_part(original, skip, len)]
  end

  ## JSON strict escape

  json_strict_jt = Codegen.jump_table(ranges, :chunk, 0x7F + 1)

  defp escape_json_strict(data, original, skip, close) do
    escape_json_strict(data, [], original, skip, close)
  end

  Enum.map(json_strict_jt, fn
    {byte, :chunk} ->
      defp escape_json_strict(<<byte, rest::bits>>, acc, original, skip, close)
           when byte === unquote(byte) do
        escape_json_strict_chunk(rest, acc, original, skip, close, 1)
      end
    {byte, _escape} ->
      defp escape_json_strict(<<byte, rest::bits>>, acc, original, skip, close)
           when byte === unquote(byte) do
        acc = [acc | escape(byte)]
        escape_json_strict(rest, acc, original, skip + 1, close)
      end
  end)
  defp escape_json_strict(<<char::utf8, rest::bits>>, acc, original, skip, close)
       when char <= 0x7FF do
    escape_json_strict_chunk(rest, acc, original, skip, close, 2)
  end
  defp escape_json_strict(<<char::utf8, rest::bits>>, acc, original, skip, close)
       when char <= 0xFFFF do
    escape_json_strict_chunk(rest, acc, original, skip, close, 3)
  end
  defp escape_json_strict(<<_char::utf8, rest::bits>>, acc, original, skip, close) do
    escape_json_strict_chunk(rest, acc, original, skip, close, 4)
  end
  defp escape_json_strict(<<>>, acc, _original, _skip, :close) do
    [acc, ?\"]
  end
  defp escape_json_strict(<<>>, acc, _original, _skip, :noclose) do
    acc
  end
  defp escape_json_strict(<<byte, _rest::bits>>, _acc, original, _skip, _close) do
    throw {:invalid_byte, byte, original}
  end

  Enum.map(json_strict_jt, fn
    {byte, :chunk} ->
      defp escape_json_strict_chunk(<<byte, rest::bits>>, acc, original, skip, close, len)
           when byte === unquote(byte) do
        escape_json_strict_chunk(rest, acc, original, skip, close, len + 1)
      end
    {byte, _escape} ->
      defp escape_json_strict_chunk(<<byte, rest::bits>>, acc, original, skip, close, len)
           when byte === unquote(byte) do
        part = binary_part(original, skip, len)
        acc = [acc, part | escape(byte)]
        escape_json_strict(rest, acc, original, skip + len + 1, close)
      end
  end)
  defp escape_json_strict_chunk(<<char::utf8, rest::bits>>, acc, original, skip, close, len)
       when char <= 0x7FF do
    escape_json_strict_chunk(rest, acc, original, skip, close, len + 2)
  end
  defp escape_json_strict_chunk(<<char::utf8, rest::bits>>, acc, original, skip, close, len)
       when char <= 0xFFFF do
    escape_json_strict_chunk(rest, acc, original, skip, close, len + 3)
  end
  defp escape_json_strict_chunk(<<_char::utf8, rest::bits>>, acc, original, skip, close, len) do
    escape_json_strict_chunk(rest, acc, original, skip, close, len + 4)
  end
  defp escape_json_strict_chunk(<<>>, acc, original, skip, :close, len) do
    part = binary_part(original, skip, len)
    [acc, part, ?\"]
  end
  defp escape_json_strict_chunk(<<>>, acc, original, skip, :noclose, len) do
    [acc | binary_part(original, skip, len)]
  end
  defp escape_json_strict_chunk(<<byte, _rest::bits>>, _acc, original, _skip, _close, _len) do
    throw {:invalid_byte, byte, original}
  end
end

defprotocol Antidote.Encoder do
  def encode(value, opts)
end

# The following implementations are formality - they are already covered
# by  the main encoding mechanism above, but exist mostly for documentation
# purposes and if anybody had the idea to call the protocol directly.

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
