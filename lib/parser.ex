# TODO: guard against too large floats

defmodule Antidote.Parser do
  import Bitwise

  def parse(data) when is_binary(data) do
    value(data, data, 0, [:terminate])
  end

  number = :orddict.from_list(Enum.map('123456789', &{&1, :number}))
  whitespace = :orddict.from_list(Enum.map('\s\n\t\r', &{&1, :value}))
  # Having ?{ and ?[ confuses the syntax highlighter :(
  values = :orddict.from_list([{hd('{'), :object}, {hd('['), :array},
                               {hd(']'), :empty_array},
                               {?-, :number}, {?0, :number_zero},
                               {?\", :string}, {?n, :null},
                               {?t, :value_true}, {?f, :value_false}])
  merge = fn _k, _v1, _v2 -> raise "duplicate!" end
  orddict = Enum.reduce([number, whitespace, values],
    &:orddict.merge(merge, &1, &2))
  dispatch = Enum.with_index(:array.to_list(:array.from_orddict(orddict, :error)))

  for {action, byte} <- dispatch, not action in [:number, :number_zero, :string] do
    defp value(<<unquote(byte), rest::bits>>, original, skip, stack) do
      unquote(action)(rest, original, skip + 1, stack)
    end
  end
  for {:number, byte} <- dispatch do
    defp value(<<unquote(byte), rest::bits>>, original, skip, stack) do
      number(rest, original, skip, stack, 1)
    end
  end
  defp value(<<?\", rest::bits>>, original, skip, stack) do
    string(rest, original, skip + 1, stack, 0)
  end
  defp value(<<?0, rest::bits>>, original, skip, stack) do
    number_zero(rest, original, skip, stack)
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

  defp number_zero(<<?., rest::bits>>, original, skip, stack) do
    number_frac(rest, original, skip, stack, 2)
  end
  defp number_zero(<<e, rest::bits>>, original, skip, stack) when e in 'eE' do
    number_exp_copy(rest, original, skip + 2, stack, "0")
  end
  defp number_zero(<<rest::bits>>, original, skip, stack) do
    continue(rest, original, skip + 1, stack, 0)
  end

  @compile {:inline, array: 4}

  defp array(rest, original, skip, stack) do
    value(rest, original, skip, [:array, [] | stack])
  end

  defp empty_array(rest, original, skip, stack) do
    case stack do
      [:array, [] | stack] ->
        continue(rest, original, skip, stack, [])
      _ ->
        error(original, skip)
    end
  end

  whitespace = Enum.map(whitespace, &elem(&1, 0))

  defp array(<<byte, rest::bits>>, original, skip, stack, value)
       when byte in unquote(whitespace) do
    array(rest, original, skip + 1, stack, value)
  end
  defp array(<<close, rest::bits>>, original, skip, stack, value)
       when close === hd(']') do
    [acc | stack] = stack
    continue(rest, original, skip + 1, stack, :lists.reverse([value | acc]))
  end
  defp array(<<?,, rest::bits>>, original, skip, stack, value) do
    [acc | stack] = stack
    value(rest, original, skip + 1, [:array, [value | acc] | stack])
  end
  defp array(<<_rest::bits>>, original, skip, _stack, _value) do
    error(original, skip)
  end

  @compile {:inline, object: 4}

  defp object(<<rest::bits>>, original, skip, stack) do
    key(rest, original, skip, [[] | stack])
  end

  defp object(<<byte, rest::bits>>, original, skip, stack, value)
       when byte in unquote(whitespace) do
    object(rest, original, skip + 1, stack, value)
  end
  defp object(<<close, rest::bits>>, original, skip, stack, value)
       when close === hd('}') do
    [key, acc | stack] = stack
    final = [{key, value} | acc]
    continue(rest, original, skip + 1, stack, :maps.from_list(final))
  end
  defp object(<<?,, rest::bits>>, original, skip, stack, value) do
    [key, acc | stack] = stack
    acc = [{key, value} | acc]
    key(rest, original, skip + 1, [acc | stack])
  end

  defp key(<<byte, rest::bits>>, original, skip, stack)
       when byte in unquote(whitespace) do
    key(rest, original, skip + 1, stack)
  end
  defp key(<<close, rest::bits>>, original, skip, stack)
       when close === hd('}') do
    case stack do
      [[] | stack] ->
        continue(rest, original, skip + 1, stack, %{})
      _ ->
        error(original, skip)
    end
  end
  defp key(<<?\", rest::bits>>, original, skip, stack) do
    string(rest, original, skip + 1, [:key | stack], 0)
  end

  defp key(<<byte, rest::bits>>, original, skip, stack, value)
       when byte in unquote(whitespace) do
    key(rest, original, skip + 1, stack, value)
  end
  defp key(<<?:, rest::bits>>, original, skip, stack, value) do
    value(rest, original, skip + 1, [:object, value | stack])
  end
  defp key(<<_rest::bits>>, original, skip, stack, _value) do
    error(original, skip)
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

  defp string(<<?\", rest::bits>>, original, skip, stack, len) do
    string = binary_part(original, skip, len)
    continue(rest, original, skip + len + 1, stack, string)
  end
  defp string(<<?\\, rest::bits>>, original, skip, stack, len) do
    part = binary_part(original, skip, len)
    escape(rest, original, skip + len, stack, part)
  end
  # TODO: validate more tightly
  defp string(<<_byte, rest::bits>>, original, skip, stack, len) do
    string(rest, original, skip, stack, len + 1)
  end
  # defp string(<<_rest::bits>>, original, skip, _stack, _len) do
  #   error(original, skip)
  # end

  defp string(<<?\", rest::bits>>, original, skip, stack, acc, len) do
    last = binary_part(original, skip, len)
    string = IO.iodata_to_binary([acc | last])
    continue(rest, original, skip + len + 1, stack, string)
  end
  defp string(<<?\\, rest::bits>>, original, skip, stack, acc, len) do
    part = binary_part(original, skip, len)
    escape(rest, original, skip + len, stack, [acc | part])
  end
  # TODO: validate more tightly
  defp string(<<_byte, rest::bits>>, original, skip, stack, acc, len) do
    string(rest, original, skip, stack, acc, len + 1)
  end
  # defp string(<<_rest::bits>>, original, skip, _stack, _acc, _len) do
  #   error(original, skip)
  # end

  escapes = Enum.zip('\b\t\n\f\r"\\/', 'btnfr"\\/')

  for {byte, escape} <- escapes do
    defp escape(<<unquote(byte), rest::bits>>, original, skip, stack, acc) do
      string(rest, original, skip + 2, stack, [acc, unquote(escape)], 0)
    end
  end
  defp escape(<<?u, rest::bits>>, original, skip, stack, acc) do
    escapeu(rest, original, skip, stack, acc)
  end
  defp escape(<<_rest::bits>>, original, skip, _stack, _acc) do
    error(original, skip)
  end

  defp escapeu(<<a1, b1, c1, d1, ?\\, ?u, a2, b2, c2, d2, rest::bits>>, original, skip, stack, acc)
       when a1 in 'dD' and a2 in 'dD'
       and (b1 in '89abAB')
       and (b2 in ?c..?f or b2 in ?C..?F) do
    try do
      hi = List.to_integer([a1, b1, c1, d1], 16)
      lo = List.to_integer([a2, b2, c2, d2], 16)
      {hi, lo}
    rescue
      ArgumentError ->
        raise "error"
    else
      {hi, lo} ->
        codepoint = 0x10000 + ((hi &&& 0x03FF) <<< 10) + (lo &&& 0x03FF)
        string(rest, original, skip + 12, stack, [acc, <<codepoint::utf8>>], 0)
    end
  end
  defp escapeu(<<escape::binary-4, rest::bits>>, original, skip, stack, acc) do
    try do
      String.to_integer(escape, 16)
    rescue
      ArgumentError ->
        raise "error"
    else
      codepoint ->
        string(rest, original, skip + 6, stack, [acc, <<codepoint::utf8>>], 0)
    end
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
      :array     -> array(rest, original, skip, stack, value)
      :key       -> key(rest, original, skip, stack, value)
      :object    -> object(rest, original, skip, stack, value)
    end
  end

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
