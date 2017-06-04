defmodule Antidote.Encode do
  @type escape :: :json | :unicode | :html | :javascript
  @type validate :: boolean
  @type maps :: :naive | :strict

  # @compile :native

  def encode(value, opts) do
    escape = escape_function(opts)
    encode_map = encode_map_function(opts)
    encode_dispatch(value, escape, encode_map, opts)
  end

  defp encode_map_function(%{maps: maps}) do
    case maps do
      :naive -> &encode_map_naive/4
      :strict -> &encode_map_strict/4
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
    [?\[, encode_dispatch(head, escape, encode_map, opts)
     | encode_list_loop(tail, escape, encode_map, opts)]
  end

  defp encode_list_loop([], _escape, _encode_map, _opts) do
    [?\]]
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
        key = encode_key(key, escape)
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
    key = encode_key(key, escape)
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

  z16 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  escapes = quote(do: [
   # 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
    ?u, ?u, ?u, ?u, ?u, ?u, ?u, ?u, ?b, ?t, ?n, ?u, ?f, ?r, ?u, ?u, # 00
    ?u, ?u, ?u, ?u, ?u, ?u, ?u, ?u, ?u, ?u, ?u, ?u, ?u, ?u, ?u, ?u, # 10
     0,  0,?\",  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, # 20
    unquote_splicing(z16), unquote_splicing(z16),                   # 30~4F
     0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,?\\,  0,  0,  0, # 50
    unquote_splicing(z16), unquote_splicing(z16),                   # 60~7F
    unquote_splicing(z16), unquote_splicing(z16),                   # 80~9F
    unquote_splicing(z16), unquote_splicing(z16),                   # A0~BF
    unquote_splicing(z16), unquote_splicing(z16),                   # C0~DF
    unquote_splicing(z16), unquote_splicing(z16),                   # E0~FF
  ])

  defp escape_json_naive(data, original, skip, close) do
    escape_json_naive(data, [], original, skip, close)
  end

  for {action, byte} <- Enum.with_index(escapes) do
    case action do
      ?u ->
        sequence = to_string(:io_lib.format("\\u~4.16.0B", [byte]))
        defp escape_json_naive(<<unquote(byte), rest::bits>>, acc, original, skip, close) do
          acc = [acc | unquote(sequence)]
          escape_json_naive(rest, acc, original, skip, close)
        end
      0 ->
        defp escape_json_naive(<<unquote(byte), rest::bits>>, acc, original, skip, close) do
          escape_json_naive_chunk(rest, acc, original, skip, close, 1)
        end
      c ->
        sequence = <<?\\, c>>
        defp escape_json_naive(<<unquote(byte), rest::bits>>, acc, original, skip, close) do
          acc = [acc | unquote(sequence)]
          escape_json_naive(rest, acc, original, skip, close)
        end
    end
  end

  defp escape_json_naive(<<>>, acc, _original, _skip, :close) do
    [acc, ?\"]
  end
  defp escape_json_naive(<<>>, acc, _original, _skip, :noclose) do
    acc
  end

  defp escape_json_naive_chunk(<<byte, rest::bits>>, acc, original, skip, close, len)
       when byte >= 0x20 do
    escape_json_naive_chunk(rest, acc, original, skip, close, len + 1)
  end
  defp escape_json_naive_chunk(<<?\", rest::bits>>, acc, original, skip, close, len) do
    part = binary_part(original, skip, len)
    acc = [acc, part | "\\\""]
    escape_json_naive(rest, acc, original, skip + len, close)
  end
  defp escape_json_naive_chunk(<<?\\, rest::bits>>, acc, original, skip, close, len) do
    part = binary_part(original, skip, len)
    acc = [acc, part | "\\\\"]
    escape_json_naive(rest, acc, original, skip + len, close)
  end
  defp escape_json_naive_chunk(<<rest::bits>>, acc, original, skip, close, len) do
    part = binary_part(original, skip, len)
    acc = [acc | part]
    escape_json_naive(rest, acc, original, skip + len, close)
  end
  defp escape_json_naive_chunk(<<>>, acc, original, skip, :close, len) do
    part = binary_part(original, skip, len)
    [acc, part, ?\"]
  end
  defp escape_json_naive_chunk(<<>>, acc, original, skip, :noclose, len) do
    [acc | binary_part(original, skip, len)]
  end
end

defprotocol Antidote.Encoder do
  def encode(value, opts)
end
