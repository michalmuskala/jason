# TODO: guard against too large floats

defmodule Antidote.Parser do
  def parse(data) when is_binary(data) do
    value(data, data, 0, [:terminate])
  end

  number = :orddict.from_list(Enum.map('123456789', &{&1, :number}))
  whitespace = :orddict.from_list(Enum.map('\s\n\t\r', &{&1, :value}))
  # Having ?{ and ?[ confuses the syntax highlighter :(
  values = :orddict.from_list([{hd('{'), :object}, {hd('['), :array},
                               {?-, :number_minus}, {?0, :number_zero},
                               {?\", :string}, {?n, :null},
                               {?t, :value_true}, {?f, :value_false}])
  merge = fn _k, _v1, _v2 -> raise "duplicate!" end
  orddict = Enum.reduce([number, whitespace, values],
    &:orddict.merge(merge, &1, &2))
  dispatch = Enum.with_index(:array.to_list(:array.from_orddict(orddict, :error)))

  for {action, byte} <- dispatch, action != :number do
    defp value(<<unquote(byte), rest::bits>>, original, skip, stack) do
      unquote(action)(rest, original, skip + 1, stack)
    end
  end
  for {:number, byte} <- dispatch do
    defp value(<<unquote(byte), rest::bits>>, original, skip, stack) do
      number(rest, original, skip, stack, 1)
    end
  end
  defp value(<<rest::bits>>, original, skip, stack) do
    error(original, skip)
  end

  digits = '0123456789'

  defp number(<<byte, rest::bits>>, original, skip, stack, len)
       when byte in unquote(digits) do
    number(rest, original, skip, stack, len + 1)
  end
  defp number(<<?., rest::bits>>, original, skip, stack, len) do
    number_frac(rest, original, skip, stack, len + 1)
  end
  defp number(<<e, rest::bits>>, original, skip, stack, len) when e in 'eE' do
    prefix = binary_part(original, skip, len)
    number_exp_copy(rest, original, skip + len + 1, stack, prefix)
  end
  defp number(<<rest::bits>>, original, skip, stack, len) do
    int = String.to_integer(binary_part(original, skip, len))
    continue(rest, original, skip + len, stack, int)
  end

  defp number_frac(<<byte, rest::bits>>, original, skip, stack, len)
       when byte in unquote(digits) do
    number_frac_cont(rest, original, skip, stack, len + 1)
  end
  defp number_frac(<<_rest::bits>>, original, skip, _stack, len) do
    error(original, skip + len)
  end

  defp number_frac_cont(<<byte, rest::bits>>, original, skip, stack, len)
       when byte in unquote(digits) do
    number_frac_cont(rest, original, skip, stack, len + 1)
  end
  defp number_frac_cont(<<e, rest::bits>>, original, skip, stack, len)
       when e in 'eE' do
    number_exp(rest, original, skip, stack, len + 1)
  end
  defp number_frac_cont(<<rest::bits>>, original, skip, stack, len) do
    float = String.to_float(binary_part(original, skip, len))
    continue(rest, original, skip + len, stack, float)
  end

  defp number_exp(<<byte, rest::bits>>, original, skip, stack, len)
       when byte in unquote(digits) do
    number_exp_cont(rest, original, skip, stack, len + 1)
  end
  defp number_exp(<<byte, rest::bits>>, original, skip, stack, len)
       when byte in '+-' do
    number_exp_sign(rest, original, skip, stack, len + 1)
  end
  defp number_exp(<<_rest::bits>>, original, skip, _stack, len) do
    error(original, skip + len)
  end

  defp number_exp_sign(<<byte, rest::bits>>, original, skip, stack, len)
       when byte in unquote(digits) do
    number_exp_cont(rest, original, skip, stack, len + 1)
  end
  defp number_exp_sign(<<_rest::bits>>, original, skip, _stack, len) do
    error(original, skip + len)
  end

  defp number_exp_cont(<<byte, rest::bits>>, original, skip, stack, len)
       when byte in unquote(digits) do
    number_exp_cont(rest, original, skip, stack, len + 1)
  end
  defp number_exp_cont(<<rest::bits>>, original, skip, stack, len) do
    float = String.to_float(binary_part(original, skip, len))
    continue(rest, original, skip + len, stack, float)
  end

  defp number_exp_copy(<<byte, rest::bits>>, original, skip, stack, prefix)
       when byte in unquote(digits) do
    number_exp_cont(rest, original, skip, stack, prefix, 1)
  end
  defp number_exp_copy(<<byte, rest::bits>>, original, skip, stack, prefix)
       when byte in '+-' do
    number_exp_sign(rest, original, skip, stack, prefix, 1)
  end
  defp number_exp(<<_rest::bits>>, original, skip, _stack, _prefix) do
    error(original, skip)
  end

  defp number_exp_sign(<<byte, rest::bits>>, original, skip, stack, prefix, len)
       when byte in unquote(digits) do
    number_exp_cont(rest, original, skip, stack, prefix, len + 1)
  end
  defp number_exp_sign(<<_rest::bits>>, original, skip, _stack, _prefix, len) do
    error(original, skip + len)
  end

  defp number_exp_cont(<<byte, rest::bits>>, original, skip, stack, prefix, len)
       when byte in unquote(digits) do
    number_exp_cont(rest, original, skip, stack, prefix, len + 1)
  end
  defp number_exp_cont(<<rest::bits>>, original, skip, stack, prefix, len) do
    string = prefix <> ".0e" <> binary_part(original, skip, len)
    float = String.to_float(string)
    continue(rest, original, skip + len, stack, float)
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

  defp error(original, skip) when skip == byte_size(original) do
    raise "unexpected EOF at position #{skip}"
  end
  defp error(original, skip) do
    case :binary.at(original, skip) do
      ascii when ascii < 127 ->
        raise "unexpected byte #{inspect ascii, base: :hex} ('#{<<ascii>>}') " <>
          "at position #{skip}"
      byte ->
        raise "unexpected byte #{inspect byte, base: :hex} " <>
          "at position #{skip}"
    end
  end

  defp continue(<<rest::bits>>, original, skip, [next | stack], value) do
    case next do
      :terminate -> terminate(rest, original, skip, stack, value)
    end
  end

  whitespace = Enum.map(whitespace, &elem(&1, 0))

  defp terminate(<<byte, rest::bits>>, original, skip, stack, value)
       when byte in unquote(whitespace) do
    terminate(rest, original, skip + 1, stack, value)
  end
  defp terminate(<<>>, _original, _skip, _stack, value) do
    value
  end
  defp terminate(<<_rest::bits>>, original, skip, _stack, _value) do
    error(original, skip)
  end
end
