defmodule Antidote.Parser do
  def parse(data) when is_binary(data) do
    value(data, data, 0, [:whitespace, :terminate])
  end

  number = :orddict.from_list(Enum.map('123456789', &{&1, :number}))
  whitespace = :orddict.from_list(Enum.map('\s\n\t\r', &{&1, :whitespace}))
  # Having ?{ and ?[ confuses the syntax highlighter :(
  values = :orddict.from_list([{hd('{'), :object}, {hd('['), :array},
                               {?-, :number_minus}, {?0, :number_zero},
                               {?\", :string}, {?n, :null},
                               {?t, :value_true}, {?f, :value_false}])
  merge = fn _k, _v1, _v2 -> raise "duplicate!" end
  orddict = Enum.reduce([number, whitespace, values],
    &:orddict.merge(merge, &1, &2))
  dispatch = Enum.with_index(:array.to_list(:array.from_orddict(orddict, :error)))

  for {action, byte} <- dispatch do
    defp value(<<unquote(byte), rest::bits>>, original, skip, stack) do
      unquote(action)(rest, original, skip + 1, stack)
    end
  end
  defp value(<<rest::bits>>, original, skip, stack) do
    error(original, skip)
  end

  defp number(<<rest::bits>>, original, skip, stack) do
    raise "not there"
  end

  defp number_minus(<<rest::bits>>, original, skip, stack) do
    raise "not there"
  end

  defp number_zero(<<rest::bits>>, original, skip, stack) do
    raise "not there"
  end

  defp array(<<rest::bits>>, original, skip, stack) do
    raise "not there"
  end

  defp object(<<rest::bits>>, original, skip, stack) do
    raise "not there"
  end

  whitespace = Enum.map(whitespace, &elem(&1, 0))

  defp whitespace(<<byte, rest::bits>>, original, skip, stack)
       when byte in unquote(whitespace) do
    whitespace(rest, original, skip + 1, stack)
  end
  defp whitespace(<<rest::bits>>, original, skip, [value | stack]) do
    continue(rest, original, skip, stack, value)
  end

  defp null(<<"ull", rest::bits>>, original, skip, stack) do
    continue(rest, original, skip + 3, stack, nil)
  end
  defp null(<<_rest::bits>>, original, skip, _stack) do
    error(original, skip)
  end

  defp value_true(<<"rue", rest::bits>>, original, skip, stack) do
    continue(rest, original, skip + 3, stack, true)
  end
  defp value_true(<<_rest::bits>>, original, skip, _stack) do
    error(original, skip)
  end

  defp value_false(<<"alse", rest::bits>>, original, skip, stack) do
    continue(rest, original, skip + 4, stack, false)
  end
  defp value_false(<<_rest::bits>>, original, skip, _stack) do
    error(original, skip)
  end

  defp string(<<rest::bits>>, original, skip, stack) do
    raise "not supported"
  end

  defp error(<<_rest::bits>>, original, skip, _stack) do
    error(original, skip)
  end

  defp error(original, skip) do
    byte = :binary.at(original, skip)
    raise "unknown byte #{inspect byte, base: :hex} at position #{skip}"
  end

  defp continue(<<rest::bits>>, original, skip, [next | stack], value) do
    case next do
      :whitespace -> whitespace(rest, original, skip, [value | stack])
      :terminate -> terminate(rest, original, skip, stack, value)
    end
  end

  defp terminate(<<>>, _original, _skip, _stack, value) do
    value
  end
  defp terminate(<<_rest::bits>>, original, skip, _stack, _value) do
    error(original, skip)
  end
end
