defmodule Antidote.Encode do
  @type escape :: :json | :unicode | :html | :javascript
  @type validate :: boolean
  @type maps :: :naive | :strict

  @compile :native

  def encode(value, opts) do
    escape = escape_function(opts)
    encode_map = encode_map_function(opts)
    encode_dispatch(value, encode_map, escape, opts)
  end

  defp encode_map_function(%{maps: maps}) do
    case maps do
      :naive -> &encode_map_naive/4
      # :strict -> &encode_map_strict/2
      :strict -> fn _,_,_,_ -> raise "not supported" end
    end
  end

  defp escape_function(%{escape: escape, validate: validate}) do
    case {escape, validate} do
      # {:json, true} -> &escape_json_validate/4
      {:json, false} -> &escape_json_naive/4
      # {:unicode, _} -> &escape_unicode/3
      # {:html, true} -> &escape_html_validate/3
      # {:html, false} -> &escape_html_naive/3
      # {:javascript, true} -> &escape_javascript_validate/3
      # {:javascript, false} -> &escape_javascript_naive/3
      _ -> fn _,_,_,_ -> raise "not supported" end
    end
  end

  defp encode_dispatch(value, _encode_map, escape, _opts) when is_atom(value) do
    do_encode_atom(value, escape)
  end

  defp encode_dispatch(value, _encode_map, escape, _opts) when is_binary(value) do
    do_encode_string(value, escape)
  end

  defp encode_dispatch(value, _encode_map, _escape, _opts) when is_integer(value) do
    encode_integer(value)
  end

  defp encode_dispatch(value, _encode_map, _escape, _opts) when is_float(value) do
    encode_float(value)
  end

  defp encode_dispatch(value, encode_map, escape, opts) when is_list(value) do
    encode_list(value, encode_map, escape, opts)
  end

  defp encode_dispatch(%{__struct__: module} = value, _encode_map, _escape, opts) do
    encode_struct(value, opts, module)
  end

  defp encode_dispatch(value, encode_map, escape, opts) when is_map(value) do
    encode_map.(value, encode_map, escape, opts)
  end

  defp encode_dispatch(value, _encode_map, _escape, opts) do
    Antidote.Encoder.encode(value, opts)
  end

  @compile {:inline,
            do_encode_atom: 2, do_encode_string: 2, encode_integer: 1,
            encode_float: 1, encode_list: 4, encode_struct: 3}

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
    encode_list(list, encode_map, escape, opts)
  end

  defp encode_list([], _encode_map, _escape, _opts) do
    "[]"
  end

  defp encode_list([head | tail], encode_map, escape, opts) do
    [?\[, encode_dispatch(head, encode_map, escape, opts)
     | encode_list_loop(tail, encode_map, escape, opts)]
  end

  defp encode_list_loop([], _encode_map, _escape, _opts) do
    [?\]]
  end

  defp encode_list_loop([head | tail], encode_map, escape, opts) do
    [?,, encode_dispatch(head, encode_map, escape, opts)
     | encode_list_loop(tail, encode_map, escape, opts)]
  end

  def encode_map(value, opts) do
    escape = escape_function(opts)
    encode_map = encode_map_function(opts)
    encode_map.(value, encode_map, escape, opts)
  end

  defp encode_map_naive(empty, _encode_map, _escape, _opts) when empty == %{} do
    "{}"
  end

  defp encode_map_naive(value, encode_map, escape, opts) do
    [{key, value} | tail] = Map.to_list(value)
    ["{\"", encode_key(key, escape), "\":",
     encode_dispatch(value, encode_map, escape, opts)
     | encode_map_naive_loop(tail, encode_map, escape, opts)]
  end

  defp encode_map_naive_loop([], _encode_map, _escape, _opts) do
    [?\}]
  end

  defp encode_map_naive_loop([{key, value} | tail], encode_map, escape, opts) do
    [",\"", encode_key(key, escape), "\":",
     encode_dispatch(value, encode_map, escape, opts) |
     encode_map_naive_loop(tail, encode_map, escape, opts)]
  end

  defp encode_struct(value, _opts, module)
       when module in [Date, Time, NaiveDateTime, DateTime] do
    [?\", module.to_iso8601(value), ?\"]
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

  defp encode_key(atom, escape) when is_atom(atom) do
    string = Atom.to_string(atom)
    escape.(string, string, 0, :noclose)
  end

  defp encode_key(string, escape) when is_binary(string) do
    escape.(string, string, 0, :noclose)
  end

  def encode_string(string, opts) do
    escape = escape_function(opts)
    do_encode_string(string, escape)
  end

  defp do_encode_string(string, escape) do
    [?\" | escape.(string, string, 0, :close)]
  end

  escape_bytes = '"\\\n\t\r\f\b'
  @escapes Enum.zip('"\\\n\t\r\f\b', '"\\ntrfb')
  @control Enum.to_list(0..0x1F) -- escape_bytes
  @regular Enum.to_list(0x20..0xFF) -- escape_bytes

  for {byte, escape} <- @escapes do
    defp escape_json_naive(<<unquote(byte), rest::bits>>, original, skip, close) do
      [unquote(<<?\\, escape>>) | escape_json_naive(rest, original, skip + 1, close)]
    end
  end
  for byte <- @control do
    sequence = to_string(:io_lib.format("\\u~4.16.0B", [byte]))
    defp escape_json_naive(<<unquote(byte), rest::bits>>, original, skip, close) do
      [unquote(sequence) | escape_json_naive(rest, original, skip + 1, close)]
    end
  end
  for byte <- @regular do
    defp escape_json_naive(<<unquote(byte), rest::bits>>, original, skip, close) do
      escape_json_naive_chunk(rest, original, skip, close, 1)
    end
  end
  defp escape_json_naive(<<>>, _original, _skip, :close) do
    [?\"]
  end
  defp escape_json_naive(<<>>, _original, _skip, :noclose) do
    []
  end

  for {byte, escape} <- @escapes, byte >= 0x20 do
    defp escape_json_naive_chunk(<<unquote(byte), rest::bits>>, original, skip, close, len) do
      part = binary_part(original, skip, len)
      new_original = binary_part(original, len, byte_size(original) - len)
      [part, unquote(<<?\\, escape>>)
       | escape_json_naive(rest, new_original, 0, close)]
    end
  end
  defp escape_json_naive_chunk(<<byte, rest::bits>>, original, skip, close, len)
       when byte >= 0x20 do
    escape_json_naive_chunk(rest, original, skip, close, len + 1)
  end
  defp escape_json_naive_chunk(<<rest::bits>>, original, skip, close, len) do
    part = binary_part(original, skip, len)
    new_original = binary_part(original, len, byte_size(original) - len)
    [part | escape_json_naive(rest, new_original, 0, close)]
  end
  defp escape_json_naive_chunk(<<>>, original, skip, :close, len) do
    part = binary_part(original, skip, len)
    [part, ?\"]
  end
  defp escape_json_naive_chunk(<<>>, original, skip, :noclose, len) do
    binary_part(original, skip, len)
  end
end

defprotocol Antidote.Encoder do
  def encode(value, opts)
end
