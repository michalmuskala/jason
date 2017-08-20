defmodule Antidote.Codegen do
  @moduledoc false

  import Bitwise

  @digits Enum.concat([?0..?9, ?A..?F, ?a..?f])

  def jump_table(ranges, default) do
    ranges
    |> ranges_to_orddict()
    |> :array.from_orddict(default)
    |> :array.to_orddict()
  end

  def jump_table(ranges, default, max) do
    ranges
    |> ranges_to_orddict()
    |> :array.from_orddict(default)
    |> resize(max)
    |> :array.to_orddict()
  end

  defp resize(array, size), do: :array.resize(size, array)

  defp ranges_to_orddict(ranges) do
    ranges
    |> Enum.flat_map(fn
      {int, value} when is_integer(int) ->
        [{int, value}]
      {enum, value} ->
        Enum.map(enum, &{&1, value})
    end)
    |> :orddict.from_list()
  end

  def unicode_escapes(chars1 \\ @digits, chars2 \\ @digits) do
    for char1 <- chars1, char2 <- chars2 do
      {(char1 <<< 8) + char2, integer8(char1, char2)}
    end
  end

  defp integer8(char1, char2) do
    (integer4(char1) <<< 4) + integer4(char2)
  end

  defp integer4(char) when char in ?0..?9, do: char - ?0
  defp integer4(char) when char in ?A..?F, do: char - ?A + 10
  defp integer4(char) when char in ?a..?f, do: char - ?a + 10

  defp token_error_clause(original, skip, len) do
    quote do
      _ ->
        token_error(unquote_splicing([original, skip, len]))
    end
  end

  defmacro escapeu_first(int, last, rest, original, skip, stack, key_decode, acc) do
    clauses = escapeu_first_clauses(last, rest, original, skip, stack, key_decode, acc)
    quote location: :keep do
      case unquote(int) do
        unquote(clauses ++ token_error_clause(original, skip, 6))
      end
    end
  end

  defp escapeu_first_clauses(last, rest, original, skip, stack, key_decode, acc) do
    for {int, first} <- unicode_escapes(),
        not (first in 0xDC..0xDF) do
      escapeu_first_clause(int, first, last, rest, original, skip, stack, key_decode, acc)
    end
  end

  defp escapeu_first_clause(int, first, last, rest, original, skip, stack, key_decode, acc)
       when first in 0xD8..0xDB do
    hi =
      quote bind_quoted: [first: first, last: last] do
        0x10000 + ((((first &&& 0x03) <<< 8) + last) <<< 10)
      end
    args = [rest, original, skip, stack, key_decode, acc, hi]
    [clause] =
      quote location: :keep do
        unquote(int) -> escape_surrogate(unquote_splicing(args))
      end
    clause
  end

  defp escapeu_first_clause(int, first, last, rest, original, skip, stack, key_decode, acc)
       when first <= 0x00 do
    skip = quote do: (unquote(skip) + 6)
    acc =
      quote bind_quoted: [acc: acc, first: first, last: last] do
        if last <= 0x7F do
          # 0?????
          [acc, last]
        else
          # 110xxxx??  10?????
          byte1 = ((0b110 <<< 5) + (first <<< 2)) + (last >>> 6)
          byte2 = (0b10 <<< 6) + (last &&& 0b111111)
          [acc, byte1, byte2]
        end
      end
    args = [rest, original, skip, stack, key_decode, acc, 0]
    [clause] =
      quote location: :keep do
        unquote(int) -> string(unquote_splicing(args))
      end
    clause
  end

  defp escapeu_first_clause(int, first, last, rest, original, skip, stack, key_decode, acc)
       when first <= 0x07 do
    skip = quote do: (unquote(skip) + 6)
    acc =
      quote bind_quoted: [acc: acc, first: first, last: last] do
        # 110xxx??  10??????
        byte1 = ((0b110 <<< 5) + (first <<< 2)) + (last >>> 6)
        byte2 = (0b10 <<< 6) + (last &&& 0b111111)
        [acc, byte1, byte2]
      end
    args = [rest, original, skip, stack, key_decode, acc, 0]
    [clause] =
      quote location: :keep do
        unquote(int) -> string(unquote_splicing(args))
      end
    clause
  end

  defp escapeu_first_clause(int, first, last, rest, original, skip, stack, key_decode, acc)
       when first <= 0xFF do
    skip = quote do: (unquote(skip) + 6)
    acc =
      quote bind_quoted: [acc: acc, first: first, last: last] do
        # 1110xxxx  10xxxx??  10??????
        byte1 = (0b1110 <<< 4) + (first >>> 4)
        byte2 = ((0b10 <<< 6) + ((first &&& 0b1111) <<< 2)) + (last >>> 6)
        byte3 = (0b10 <<< 6) + (last &&& 0b111111)
        [acc, byte1, byte2, byte3]
      end
    args = [rest, original, skip, stack, key_decode, acc, 0]
    [clause] =
      quote location: :keep do
        unquote(int) -> string(unquote_splicing(args))
      end
    clause
  end

  defmacro escapeu_last(int, original, skip) do
    clauses = escapeu_last_clauses()
    quote location: :keep do
      case unquote(int) do
        unquote(clauses ++ token_error_clause(original, skip, 6))
      end
    end
  end

  defp escapeu_last_clauses() do
    for {int, last} <- unicode_escapes() do
      [clause] =
        quote do
          unquote(int) -> unquote(last)
        end
      clause
    end
  end

  defmacro escapeu_surrogate(int, last, rest, original, skip, stack, key_decode, acc,
             hi) do
    clauses = escapeu_surrogate_clauses(last, rest, original, skip, stack, key_decode, acc, hi)
    quote location: :keep do
      case unquote(int) do
        unquote(clauses ++ token_error_clause(original, skip, 12))
      end
    end
  end

  defp escapeu_surrogate_clauses(last, rest, original, skip, stack, key_decode, acc, hi) do
    digits1 = 'Dd'
    digits2 = Stream.concat([?C..?F, ?c..?f])
    for {int, first} <- unicode_escapes(digits1, digits2) do
      escapeu_surrogate_clause(int, first, last, rest, original, skip, stack, key_decode, acc, hi)
    end
  end

  defp escapeu_surrogate_clause(int, first, last, rest, original, skip, stack, key_decode, acc, hi) do
    skip = quote do: unquote(skip) + 12
    acc =
      quote bind_quoted: [acc: acc, first: first, last: last, hi: hi] do
        lo = ((first &&& 0x03) <<< 8) + last
        [acc | <<(hi + lo)::utf8>>]
      end
    args = [rest, original, skip, stack, key_decode, acc, 0]
    [clause] =
      quote do
        unquote(int) ->
          string(unquote_splicing(args))
      end
    clause
  end
end
