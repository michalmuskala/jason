defmodule Jason.Formatter do
  @moduledoc ~S"""
  `Jason.Formatter` provides pretty-printing and minimizing functions for
  JSON-encoded binary data, with output in either string or iolist
  format.

  Input is required to be in an 8-bit-wide encoding, e.g., UTF-8.

  The functions in `Jason.Formatter` do not ensure the validity of
  their input.  Valid JSON input always produces valid JSON output,
  but invalid inputs may cause unpredictable output.
  """

  @type pretty_print_opts :: [{:indent, binary}]


  @doc ~S"""
  Returns a string containing a pretty-printed representation of `str`,
  which should contain JSON-encoded data.

  `str` may contain multiple JSON objects, optionally separated by
  whitespace (e.g., one object per line).  Objects in `pretty_print`ed
  output will be separated by newlines.

  `opts[:indent]` can be provided to set the indentation string used for
  nested objects and lists.  The default indent setting is two spaces
  (`"  "`).

  Example:

      iex> Jason.Formatter.pretty_print(~s|{"a":{"b": [1, 2]}}|)
      ~s|{
        "a": {
          "b": [
            1,
            2
          ]
        }
      }
      |
  """
  @spec pretty_print(binary, pretty_print_opts) :: binary
  def pretty_print(str, opts \\ []) when is_binary(str) do
    pretty_print_to_iolist(str, opts)
    |> :erlang.list_to_binary
  end


  @doc ~S"""
  Returns an iolist containing a pretty-printed representation of `str`.

  `opts[:indent]` can be provided to set the indentation string used for
  nested objects and lists.  The default indent setting is two spaces
  (`"  "`).
  """
  @spec pretty_print_to_iolist(binary, pretty_print_opts) :: iolist
  def pretty_print_to_iolist(str, opts \\ []) when is_binary(str) do
    indent = opts[:indent] || "  "
    depth = 0
    in_string = false
    in_backslash = false
    empty = false
    wbuf = ""

    {iolist, _state} = pp_str(str, [],
      indent, depth, in_string, in_backslash, empty, wbuf)

    iolist
  end


  @doc ~S"""
  Returns a string containing a minimized representation of `str`,
  which should contain JSON-encoded data.

  `str` may contain multiple JSON objects, optionally separated by
  whitespace (e.g., one object per line).  `minimize`d output will
  contain one object per line, with no trailing newline at the end.

  Example:

      iex> Jason.Formatter.minimize(~s|{ "a" : "b" , "c": \n\n 2}|)
      ~s|{"a":"b","c":2}|
  """
  def minimize(str) do
    minimize_to_iolist(str)
    |> :erlang.list_to_binary
  end


  @doc ~S"""
  Returns an iolist containing a minimized representation of `str`,
  which should contain JSON-encoded data.

  `str` may contain multiple JSON objects, optionally separated by
  whitespace (e.g., one object per line).  `minimize`d output will
  contain one object per line, with no trailing newline at the end.
  """
  def minimize_to_iolist(str) do
    depth = 0
    in_string = false
    in_backslash = false
    print_lf = false

    {iolist, _state} = min_str(str, [],
      depth, in_string, in_backslash, print_lf)

    iolist
  end



  #### Internal functions `pp_str` and `min_str` are designed to yield
  #### both their output iolist, and their state at the time output
  #### is returned.  This state can be used to allow processing JSON
  #### data in chunks (e.g., from `IO.read/2`).


  ## pp_str returns a tuple `{iolist, state}` containing:
  ##
  ## * an iolist representing the pretty-printed version of its input
  ## * the ending state `{indent, depth, in_string, in_backslash, empty, wbuf}`
  ##
  ## Strategy: step through input one byte at a time, keeping track of:
  ## * whether the byte is part of a JSON string, including backslashed chars
  ## * whether a list or object is empty (to render `[]` and `{}` as such,
  ##   without extra whitespace)

  @typep pp_state :: {binary, non_neg_integer, boolean, boolean, boolean, binary}

  @spec pp_str(binary, iolist, binary, non_neg_integer, boolean, boolean, boolean, binary) :: {iolist, pp_state}

  defp pp_str("", iolist, indent, depth, in_string, in_backslash, empty, wbuf) do
    {:lists.reverse(iolist),
      {indent, depth, in_string, in_backslash, empty, wbuf}}
  end

  defp pp_str(<<c::size(8), rest::binary>>, iolist,
  indent, depth, true=in_string, true=_in_backslash, empty, wbuf) do
    in_backslash = false
    pp_str(rest, [c | iolist],
      indent, depth, in_string, in_backslash, empty, wbuf)
  end

  defp pp_str(<<c::size(8), rest::binary>>, iolist,
  indent, depth, true=in_string, _in_backslash, empty, wbuf)
  when c in '\\' do
    in_backslash = true
    pp_str(rest, [c | iolist],
      indent, depth, in_string, in_backslash, empty, wbuf)
  end

  defp pp_str(<<c::size(8), rest::binary>>, iolist,
  indent, depth, true=_in_string, in_backslash, empty, wbuf)
  when c in '"' do
    in_string = false
    pp_str(rest, [c | iolist],
      indent, depth, in_string, in_backslash, empty, wbuf)
  end

  defp pp_str(<<c::size(8), rest::binary>>, iolist,
  indent, depth, true=in_string, in_backslash, empty, wbuf) do
    pp_str(rest, [c | iolist],
      indent, depth, in_string, in_backslash, empty, wbuf)
  end

  defp pp_str(<<c::size(8), rest::binary>>, iolist,
  indent, depth, in_string, in_backslash, empty, wbuf)
  when c in ' \n\r\t' do
    pp_str(rest, iolist,
      indent, depth, in_string, in_backslash, empty, wbuf)
  end

  defp pp_str(<<c::size(8), rest::binary>>, iolist,
  indent, depth, in_string, in_backslash, empty, wbuf)
  when c in '{[' do
    output = if empty, do: [wbuf, c], else: c
    empty = true
    depth = depth + 1
    wbuf = ["\n", String.duplicate(indent, depth)]
    pp_str(rest, [output | iolist],
      indent, depth, in_string, in_backslash, empty, wbuf)
  end

  defp pp_str(<<c::size(8), rest::binary>>, iolist,
  indent, depth, in_string, in_backslash, true=_empty, wbuf)
  when c in '}]' do
    empty = false
    depth = depth - 1
    trailing_newline = if depth==0, do: ["\n"], else: []
    pp_str(rest, [[c, trailing_newline] | iolist],
      indent, depth, in_string, in_backslash, empty, wbuf)
  end

  defp pp_str(<<c::size(8), rest::binary>>, iolist,
  indent, depth, in_string, in_backslash, false=empty, wbuf)
  when c in '}]' do
    depth = depth - 1
    output = ["\n", String.duplicate(indent, depth), c]
    trailing_newline = if depth==0, do: ["\n"], else: []
    pp_str(rest, [[output, trailing_newline] | iolist],
      indent, depth, in_string, in_backslash, empty, wbuf)
  end

  defp pp_str(<<c::size(8), rest::binary>>, iolist,
  indent, depth, in_string, in_backslash, _empty, wbuf)
  when c in ',' do
    empty = false
    pp_str(rest, [[c, "\n", String.duplicate(indent, depth)] | iolist],
      indent, depth, in_string, in_backslash, empty, wbuf)
  end

  defp pp_str(<<c::size(8), rest::binary>>, iolist,
  indent, depth, in_string, in_backslash, empty, wbuf)
  when c in ':' do
    pp_str(rest, [[c, " "] | iolist],
      indent, depth, in_string, in_backslash, empty, wbuf)
  end

  defp pp_str(<<c::size(8), rest::binary>>, iolist,
  indent, depth, _in_string, in_backslash, empty, wbuf) do
    output = if empty, do: [wbuf, c], else: c
    in_string = c == '"'
    empty = false
    pp_str(rest, [output | iolist],
      indent, depth, in_string, in_backslash, empty, wbuf)
  end


  ## min_str returns a tuple `{iolist, state}` containing:
  ##
  ## * an iolist representing the minimized version of its input
  ## * the ending state `{depth, in_string, in_backslash, print_lf}`
  ##
  ## Strategy: step through input one byte at a time, keeping track of:
  ## * whether the byte is part of a JSON string, including backslashed chars
  ## * whether to emit a newline before the next root-level JSON term
  ##   (so we never emit a newline at the end of the stream)

  @typep min_state :: {non_neg_integer, boolean, boolean, boolean}

  @spec min_str(binary, iolist, non_neg_integer, boolean, boolean, boolean) :: {iolist, min_state}

  defp min_str("", iolist, depth, in_string, in_backslash, print_lf) do
    {:lists.reverse(iolist),
      {depth, in_string, in_backslash, print_lf}}
  end

  defp min_str(<<c::size(8), rest::binary>>, iolist,
  depth, true=in_string, true=_in_backslash, print_lf) do
    in_backslash = false
    min_str(rest, [c | iolist],
     depth, in_string, in_backslash, print_lf)
  end

  defp min_str(<<c::size(8), rest::binary>>, iolist,
  depth, true=in_string, _in_backslash, print_lf)
  when c in '\\' do
    in_backslash = true
    min_str(rest, [c | iolist],
     depth, in_string, in_backslash, print_lf)
  end

  defp min_str(<<c::size(8), rest::binary>>, iolist,
  depth, true=_in_string, in_backslash, print_lf)
  when c in '"' do
    in_string = false
    min_str(rest, [c | iolist],
     depth, in_string, in_backslash, print_lf)
  end

  defp min_str(<<c::size(8), rest::binary>>, iolist,
  depth, true=in_string, in_backslash, print_lf) do
    min_str(rest, [c | iolist],
     depth, in_string, in_backslash, print_lf)
  end

  defp min_str(<<c::size(8), rest::binary>>, iolist,
  depth, in_string, in_backslash, print_lf)
  when c in ' \n\r\t' do
    min_str(rest, iolist,
      depth, in_string, in_backslash, print_lf)
  end

  defp min_str(<<c::size(8), rest::binary>>, iolist,
  depth, in_string, in_backslash, print_lf)
  when c in '[{' do
    lf = if depth==0 && print_lf, do: ["\n"], else: []
    print_lf = true
    depth = depth + 1
    min_str(rest, [[lf, c] | iolist],
      depth, in_string, in_backslash, print_lf)
  end

  defp min_str(<<c::size(8), rest::binary>>, iolist,
  depth, in_string, in_backslash, print_lf)
  when c in ']}' do
    depth = depth - 1
    min_str(rest, [c | iolist],
      depth, in_string, in_backslash, print_lf)
  end

  defp min_str(<<c::size(8), rest::binary>>, iolist,
  depth, _in_string, in_backslash, print_lf) do
    in_string = c == '"'
    min_str(rest, [c | iolist],
      depth, in_string, in_backslash, print_lf)
  end
end

