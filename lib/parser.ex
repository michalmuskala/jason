defmodule Antidote.Parser do
  def parse(data) when is_binary(data) do
    parse(data, data, 0)
  end

  number = :orddict.from_list(Enum.map('123456789', &{&1, :number}))
  whitespace = :orddict.from_list(Enum.map('\s\n\t\r', &{&1, :whitespace}))
  # Having ?{ and ?[ confuses the syntax highlighter :(
  values = :orddict.from_list([{hd('{'), :object}, {hd('['), :array},
                               {?-, :number_minus}, {?0, :number_zero},
                               {?\", :string}, {?n, :null},
                               {?t, :true}, {?f, :false}])
  merge = fn _k, _v1, _v2 -> raise "duplicate!" end
  orddict = Enum.reduce([number, whitespace, values],
    &:orddict.merge(merge, &1, &2))
  dispatch = :array.to_list(:array.from_orddict(orddict, :error))

  for {byte, action} <- dispatch do
    defp parse(<<byte, rest::bits>>, original, skip)
         when byte === unquote(byte) do
      unquote(action)(rest, original, skip, byte)
    end
  end
  defp parse(<<byte, rest::bits>>, original, skip) do
    error(byte, skip)
  end

  defp number(<<rest::bits>>, original, skip, byte) do
    raise "not there"
  end

  defp number_minus(<<rest::bits>>, original, skip, byte) do
    raise "not there"
  end

  defp number_zero(<<rest::bits>>, original, skip, byte) do
    raise "not there"
  end

  defp array(<<rest::bits>>, original, skip, byte) do
    raise "not there"
  end

  defp object(<<rest::bits>>, original, skip, byte) do
    raise "not there"
  end

  defp whitespace(<<rest::bits>>, original, skip, byte) do
    raise "not supported"
  end

  defp null(<<"ull", rest::bits>>, orignal, skip, byte) do
    raise "not supported"
  end

  defp unquote(true)(<<"rue", rest::bits>>, original, skip, byte) do
    raise "not supported"
  end

  defp unquote(false)(<<"alse", rest::bits>>, original, skip, byte) do
    raise "not supported"
  end

  defp error(_rest, original, skip, byte) do
    error(byte, skip)
  end

  defp error(byte, skip) do
    raise "unknown byte #{inspect byte} at position #{skip}"
  end
end
