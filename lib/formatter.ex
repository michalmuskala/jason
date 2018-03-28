defmodule Jason.Formatter do
  @moduledoc ~S"""
  `Jason.Formatter` provides pretty-printing and minimizing functions for
  JSON-encoded data.

  Input is required to be in an 8-bit-wide encoding such as UTF-8 or Latin-1,
  and is accepted in `iodata` (`binary` or `iolist`) format.

  Output is provided in either `binary` or `iolist` format.
  """

  @type opts :: [
    {:indent, iodata} |
    {:line_separator, iodata} |
    {:record_separator, iodata} |
    {:after_colon, iodata}
  ]


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
    pretty_print_to_iodata(iodata, opts)
    |> IO.iodata_to_binary
  end


  @doc ~S"""
  Returns an iolist containing a pretty-printed representation of
  JSON-encoded `iodata`.

  See `pretty_print/2` for details and options.
  """
  @spec pretty_print_to_iodata(iodata, opts) :: iodata
  def pretty_print_to_iodata(iodata, opts \\ []) do
    depth = 0
    in_str = false
    in_bs = false
    empty = false
    first = true
    opts = normalize_opts(opts)

    {output, _state} =
      pp_iodata(iodata, [], depth, in_str, in_bs, empty, first, opts)

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
    minimize_to_iodata(iodata, opts)
    |> IO.iodata_to_binary
  end


  @doc ~S"""
  Returns an iolist containing a minimized representation of
  JSON-encoded `iodata`.

  See `minimize/2` for details and options.
  """
  @spec minimize_to_iodata(iodata, opts) :: iodata
  def minimize_to_iodata(iodata, opts) do
    pretty_print_to_iodata(
      iodata,
      indent: "",
      line_separator: "",
      record_separator: opts[:record_separator] || "\n",
      after_colon: ""
    )
  end


  ## Returns a copy of `opts` with defaults applied
  @spec normalize_opts(keyword) :: opts
  defp normalize_opts(opts) do
    [
      indent: opts[:indent] || "  ",
      line_separator: opts[:line_separator] || "\n",
      record_separator: opts[:record_separator] || opts[:line_separator] || "\n",
      after_colon: opts[:after_colon] || " ",
    ]
  end


  ## Returns an iolist containing `depth` instances of `opts[:indent]`
  @spec tab(opts, non_neg_integer, iolist) :: iolist
  defp tab(opts, depth, output \\ []) do
    if depth < 1 do
      output
    else
      tab(opts, depth-1, [opts[:indent] | output])
    end
  end


  @typep pp_state :: {
    non_neg_integer,  ## depth -- current nesting depth
    boolean,          ## in_str -- is the current byte in a string?
    boolean,          ## in_bs -- does the current byte follow a backslash in a string?
    boolean,          ## empty -- is the current object or array empty?
    boolean,          ## first -- is this the first object or array in the input?
  }

  @spec pp_iodata(
    iodata,           ## input -- input data
    iodata,           ## output_acc -- output iolist (built in reverse order)
    non_neg_integer,  ## depth -- current nesting depth
    boolean,          ## in_str -- is the current byte in a string?
    boolean,          ## in_bs -- does the current byte follow a backslash in a string?
    boolean,          ## empty -- is the current object or array empty?
    boolean,          ## first -- is this the first object or array in the input?
    opts
  ) :: {iodata, pp_state}
  defp pp_iodata(input, output_acc, depth, in_str, in_bs, empty, first, opts)

  defp pp_iodata("", output_acc, depth, in_str, in_bs, empty, first, opts) do
    {:lists.reverse(output_acc), {depth, in_str, in_bs, empty, first, opts}}
  end

  defp pp_iodata([], output_acc, depth, in_str, in_bs, empty, first, opts) do
    {:lists.reverse(output_acc), {depth, in_str, in_bs, empty, first, opts}}
  end

  defp pp_iodata(<<byte::size(8), rest::binary>>, output_acc, depth, in_str, in_bs, empty, first, opts) do
    pp_byte(byte, rest, output_acc, depth, in_str, in_bs, empty, first, opts)
  end

  defp pp_iodata(byte, output_acc, depth, in_str, in_bs, empty, first, opts) when is_integer(byte) do
    pp_byte(byte, [], output_acc, depth, in_str, in_bs, empty, first, opts)
  end

  defp pp_iodata(list, output_acc, depth, in_str, in_bs, empty, first, opts) when is_list(list) do
    starting_state = {depth, in_str, in_bs, empty, first, opts}
    {reversed_output, end_state} = Enum.reduce list, {[], starting_state}, fn (item, {output_acc, state}) ->
      {depth, in_str, in_bs, empty, first, opts} = state
      {item_output, new_state} = pp_iodata(item, [], depth, in_str, in_bs, empty, first, opts)
      {[item_output | output_acc], new_state}
    end
    {[:lists.reverse(reversed_output) | output_acc], end_state}
  end


  @spec pp_byte(
    byte,             ## byte -- current byte
    iodata,           ## rest -- rest of input data
    iodata,           ## output -- output iolist (built in reverse order)
    non_neg_integer,  ## depth -- current nesting depth
    boolean,          ## in_str -- is the current byte in a string?
    boolean,          ## in_bs -- does the current byte follow a backslash in a string?
    boolean,          ## empty -- is the current object or array empty?
    boolean,          ## first -- is this the first object or array in the input?
    opts
  ) :: {iodata, pp_state}
  defp pp_byte(byte, rest, output, depth, in_str, in_bs, empty, first, opts)

  ## in string, following backslash
  defp pp_byte(byte, rest, output, depth, true=in_str, true=_in_bs, empty, first, opts) do
    in_bs = false
    pp_iodata(rest, [byte | output], depth, in_str, in_bs, empty, first, opts)
  end

  ## in string, backslash
  defp pp_byte(byte, rest, output, depth, true=in_str, _in_bs, empty, first, opts)
  when byte in '\\' do
    in_bs = true
    pp_iodata(rest, [byte | output], depth, in_str, in_bs, empty, first, opts)
  end

  ## in string, end quote
  defp pp_byte(byte, rest, output, depth, true=_in_str, in_bs, empty, first, opts)
  when byte in '"' do
    in_str = false
    pp_iodata(rest, [byte | output], depth, in_str, in_bs, empty, first, opts)
  end

  ## in string, other character
  defp pp_byte(byte, rest, output, depth, true=in_str, in_bs, empty, first, opts) do
    pp_iodata(rest, [byte | output], depth, in_str, in_bs, empty, first, opts)
  end

  ## out of string, whitespace
  defp pp_byte(byte, rest, output, depth, in_str, in_bs, empty, first, opts)
  when byte in ' \n\r\t' do
    pp_iodata(rest, output, depth, in_str, in_bs, empty, first, opts)
  end

  ## out of string, start block
  defp pp_byte(byte, rest, output, depth, in_str, in_bs, empty, first, opts)
  when byte in '{[' do
    out = cond do
      first -> byte
      empty -> [opts[:line_separator], tab(opts, depth), byte]
      depth == 0 -> [opts[:record_separator], byte]
      true -> byte
    end
    first = false
    empty = true
    depth = depth + 1
    pp_iodata(rest, [out | output], depth, in_str, in_bs, empty, first, opts)
  end

  ## out of string, end empty block
  defp pp_byte(byte, rest, output, depth, in_str, in_bs, true=_empty, first, opts)
  when byte in '}]' do
    empty = false
    depth = depth - 1
    pp_iodata(rest, [byte | output], depth, in_str, in_bs, empty, first, opts)
  end

  ## out of string, end non-empty block
  defp pp_byte(byte, rest, output, depth, in_str, in_bs, false=empty, first, opts)
  when byte in '}]' do
    depth = depth - 1
    out = [opts[:line_separator], tab(opts, depth), byte]
    pp_iodata(rest, [out | output], depth, in_str, in_bs, empty, first, opts)
  end

  ## out of string, comma
  defp pp_byte(byte, rest, output, depth, in_str, in_bs, _empty, first, opts)
  when byte in ',' do
    empty = false
    out = [byte, opts[:line_separator], tab(opts, depth)]
    pp_iodata(rest, [out | output], depth, in_str, in_bs, empty, first, opts)
  end

  ## out of string, colon
  defp pp_byte(byte, rest, output, depth, in_str, in_bs, empty, first, opts)
  when byte in ':' do
    out = [byte, opts[:after_colon]]
    pp_iodata(rest, [out | output], depth, in_str, in_bs, empty, first, opts)
  end

  ## out of string, other character (maybe start quote)
  defp pp_byte(byte, rest, output, depth, _in_str, in_bs, empty, first, opts) do
    out = if empty, do: [opts[:line_separator], tab(opts, depth), byte], else: byte
    in_str = byte in '"'
    empty = false
    pp_iodata(rest, [out | output], depth, in_str, in_bs, empty, first, opts)
  end
end

