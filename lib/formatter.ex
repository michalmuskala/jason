defmodule Jason.Formatter do
  @moduledoc ~S"""
  `Jason.Formatter` provides pretty-printing and minimizing functions for
  JSON-encoded data.

  Input is required to be in an 8-bit-wide encoding such as UTF-8 or Latin-1,
  and is accepted in `iodata` (`binary` or `iolist`) format.

  Output is provided in either `binary` or `iolist` format.
  """

  @type opts :: [
          {:indent, iodata}
          | {:line_separator, iodata}
          | {:record_separator, iodata}
          | {:after_colon, iodata}
        ]

  import Record
  defrecordp :opts, [:indent, :line, :record, :colon]

  @doc ~S"""
  Returns a binary containing a pretty-printed representation of
  JSON-encoded `iodata`.

  `iodata` may contain multiple JSON objects or arrays, optionally separated
  by whitespace (e.g., one object per line).  Objects in `pretty_print`ed
  output will be separated by newlines.  No trailing newline is emitted.

  Options:

  * `:indent` sets the indentation string used for nested objects and
    arrays.  The default indent setting is two spaces (`"  "`).
  * `:line_separator` sets the newline string used in nested objects.
    The default setting is a line feed (`"\n"`).
  * `:record_separator` sets the string printed between root-level objects
    and arrays.  The default setting is `opts[:line_separator]`.
  * `:after_colon` sets the string printed after a colon inside objects.
    The default setting is one space (`" "`).

  Example:

      iex> Jason.Formatter.pretty_print(~s|{"a":{"b": [1, 2]}}|)
      ~s|{
        "a": {
          "b": [
            1,
            2
          ]
        }
      }|
  """
  @spec pretty_print(iodata, opts) :: binary
  def pretty_print(iodata, opts \\ []) do
    iodata
    |> pretty_print_to_iodata(opts)
    |> IO.iodata_to_binary()
  end

  @doc ~S"""
  Returns an iolist containing a pretty-printed representation of
  JSON-encoded `iodata`.

  See `pretty_print/2` for details and options.
  """
  @spec pretty_print_to_iodata(iodata, opts) :: iodata
  def pretty_print_to_iodata(iodata, opts \\ []) do
    opts = parse_opts(opts, opts(indent: "  ", line: "\n", record: nil, colon: " "))
    opts = opts(opts, record: opts(opts, :record) || opts(opts, :line))

    depth = :first
    empty = false

    {output, _state} = pp_iodata(iodata, [], depth, empty, opts)

    output
  end

  @doc ~S"""
  Returns a binary containing a minimized representation of
  JSON-encoded `iodata`.

  `iodata` may contain multiple JSON objects or arrays, optionally
  separated by whitespace (e.g., one object per line).  `minimize`d
  output will contain one object per line.  No trailing newline is emitted.

  The `:record_separator` option may be given to control the string
  used as newline (default `"\n"`).  Other options are ignored.

  Example:

      iex> Jason.Formatter.minimize(~s|{ "a" : "b" , "c": \n\n 2}|)
      ~s|{"a":"b","c":2}|
  """
  @spec minimize(iodata, opts) :: binary
  def minimize(iodata, opts \\ []) do
    iodata
    |> minimize_to_iodata(opts)
    |> IO.iodata_to_binary()
  end

  @doc ~S"""
  Returns an iolist containing a minimized representation of
  JSON-encoded `iodata`.

  See `minimize/2` for details and options.
  """
  @spec minimize_to_iodata(iodata, opts) :: iodata
  def minimize_to_iodata(iodata, opts) do
    opts = parse_opts(opts, opts(indent: "", line: "", record: "\n", colon: ""))

    depth = :first
    empty = false

    {output, _state} = pp_iodata(iodata, [], depth, empty, opts)

    output
  end

  defp parse_opts(opts, defaults) do
    Enum.reduce(opts, defaults, fn
      {:indent, indent}, opts ->
        opts(opts, indent: IO.iodata_to_binary(indent))

      {:line_separator, line}, opts ->
        line = IO.iodata_to_binary(line)
        opts(opts, line: line, record: opts(opts, :record) || line)

      {:record_separator, record}, opts ->
        opts(opts, record: IO.iodata_to_binary(record))

      {:after_colon, colon}, opts ->
        opts(opts, colon: IO.iodata_to_binary(colon))
    end)
  end

  @spec tab(String.t(), non_neg_integer) :: iodata()
  ## Returns an iolist containing `depth` instances of `opts[:indent]`
  for depth <- 1..16 do
    defp tab("  ", unquote(depth)), do: unquote(String.duplicate("  ", depth))
  end

  defp tab("", _), do: ""
  defp tab(indent, depth), do: List.duplicate(indent, depth)

  defp pp_iodata(<<>>, output_acc, depth, empty, opts) do
    {output_acc, &pp_iodata(&1, &2, depth, empty, opts)}
  end

  defp pp_iodata(<<byte, rest::binary>>, output_acc, depth, empty, opts) do
    pp_byte(byte, rest, output_acc, depth, empty, opts)
  end

  defp pp_iodata([], output_acc, depth, empty, opts) do
    {output_acc, &pp_iodata(&1, &2, depth, empty, opts)}
  end

  defp pp_iodata([byte | rest], output_acc, depth, empty, opts) when is_integer(byte) do
    pp_byte(byte, rest, output_acc, depth, empty, opts)
  end

  defp pp_iodata([head | tail], output_acc, depth, empty, opts) do
    {output_acc, cont} = pp_iodata(head, output_acc, depth, empty, opts)
    cont.(tail, output_acc)
  end

  defp pp_byte(byte, rest, output, depth, empty, opts) when byte in ' \n\r\t' do
    pp_iodata(rest, output, depth, empty, opts)
  end

  defp pp_byte(byte, rest, output, depth, empty, opts) when byte in '{[' do
    {out, depth} =
      cond do
        depth == :first -> {byte, 1}
        depth == 0 -> {[opts(opts, :record), byte], 1}
        empty -> {[opts(opts, :line), tab(opts(opts, :indent), depth), byte], depth + 1}
        true -> {byte, depth + 1}
      end

    empty = true
    pp_iodata(rest, [output, out], depth, empty, opts)
  end

  defp pp_byte(byte, rest, output, depth, true = _empty, opts) when byte in '}]' do
    empty = false
    depth = depth - 1
    pp_iodata(rest, [output, byte], depth, empty, opts)
  end

  defp pp_byte(byte, rest, output, depth, false = empty, opts) when byte in '}]' do
    depth = depth - 1
    out = [opts(opts, :line), tab(opts(opts, :indent), depth), byte]
    pp_iodata(rest, [output, out], depth, empty, opts)
  end

  defp pp_byte(byte, rest, output, depth, _empty, opts) when byte in ',' do
    empty = false
    out = [byte, opts(opts, :line), tab(opts(opts, :indent), depth)]
    pp_iodata(rest, [output, out], depth, empty, opts)
  end

  defp pp_byte(byte, rest, output, depth, empty, opts) when byte in ':' do
    out = [byte, opts(opts, :colon)]
    pp_iodata(rest, [output, out], depth, empty, opts)
  end

  defp pp_byte(byte, rest, output, depth, empty, opts) do
    out = if empty, do: [opts(opts, :line), tab(opts(opts, :indent), depth), byte], else: byte
    empty = false

    if byte == ?" do
      pp_string(rest, [output, out], _in_bs = false, &pp_iodata(&1, &2, depth, empty, opts))
    else
      pp_iodata(rest, [output, out], depth, empty, opts)
    end
  end

  defp pp_string(<<>>, output_acc, in_bs, cont) do
    {output_acc, &pp_string(&1, &2, in_bs, cont)}
  end

  defp pp_string(<<?", rest::binary>>, output_acc, true = _in_bs, cont) do
    pp_string(rest, [output_acc, ?"], false, cont)
  end

  defp pp_string(<<?", rest::binary>>, output_acc, false = _in_bs, cont) do
    cont.(rest, [output_acc, ?"])
  end

  defp pp_string(<<byte>>, output_acc, in_bs, cont) do
    in_bs = not in_bs and byte == ?\\
    {[output_acc, byte], &pp_string(&1, &2, in_bs, cont)}
  end

  defp pp_string(binary, output_acc, _in_bs, cont) when is_binary(binary) do
    size = byte_size(binary)

    case :binary.match(binary, "\"") do
      :nomatch ->
        skip = size - 2
        <<_::binary-size(skip), prev, last>> = binary
        in_bs = not (prev == ?\\ and last == ?\\) or last == ?\\
        {[output_acc | binary], &pp_string(&1, &2, in_bs, cont)}

      {pos, 1} ->
        {leading, tail} = :erlang.split_binary(binary, pos + 1)
        output = [output_acc | leading]

        case :binary.at(binary, pos - 1) do
          ?\\ -> pp_string(tail, output, false, cont)
          _ -> cont.(tail, output)
        end
    end
  end

  defp pp_string([], output_acc, in_bs, cont) do
    {output_acc, &pp_string(&1, &2, in_bs, cont)}
  end

  defp pp_string([byte | rest], output_acc, in_bs, cont) when is_integer(byte) do
    cond do
      in_bs -> pp_string(rest, [output_acc, byte], false, cont)
      byte == ?" -> cont.(rest, [output_acc, byte])
      true -> pp_string(rest, [output_acc, byte], byte == ?\\, cont)
    end
  end

  defp pp_string([head | tail], output_acc, in_bs, cont) do
    {output_acc, cont} = pp_string(head, output_acc, in_bs, cont)
    cont.(tail, output_acc)
  end
end
