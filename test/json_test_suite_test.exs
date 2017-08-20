defmodule JsonTestSuite do
  use ExUnit.Case, async: true

  # Implementation-dependent tests
  i_succeeds = [
    "i_number_double_huge_neg_exp.json",
    "i_number_real_underflow.json",
    "i_number_too_big_neg_int.json",
    "i_number_too_big_pos_int.json",
    "i_number_very_big_negative_int.json",
    "i_structure_500_nested_arrays.json",
  ]
  i_fails = [
    "i_number_huge_exp.json",
    "i_number_neg_int_huge_exp.json",
    "i_number_pos_double_huge_exp.json",
    "i_number_real_neg_overflow.json",
    "i_number_real_pos_overflow.json",
    "i_object_key_lone_2nd_surrogate.json",
    "i_string_1st_surrogate_but_2nd_missing.json",
    "i_string_1st_valid_surrogate_2nd_invalid.json",
    "i_string_UTF-16LE_with_BOM.json",
    "i_string_UTF-8_invalid_sequence.json",
    "i_string_UTF8_surrogate_U+D800.json",
    "i_string_incomplete_surrogate_and_escape_valid.json",
    "i_string_incomplete_surrogate_pair.json",
    "i_string_incomplete_surrogates_escape_valid.json",
    "i_string_invalid_lonely_surrogate.json",
    "i_string_invalid_surrogate.json",
    "i_string_invalid_utf-8.json",
    "i_string_inverted_surrogates_U+1D11E.json",
    "i_string_iso_latin_1.json",
    "i_string_lone_second_surrogate.json",
    "i_string_lone_utf8_continuation_byte.json",
    "i_string_not_in_unicode_range.json",
    "i_string_overlong_sequence_2_bytes.json",
    "i_string_overlong_sequence_6_bytes.json",
    "i_string_overlong_sequence_6_bytes_null.json",
    "i_string_truncated-utf-8.json",
    "i_string_utf16BE_no_BOM.json",
    "i_string_utf16LE_no_BOM.json",
    "i_structure_UTF-8_BOM_empty_object.json",
  ]

  for path <- Path.wildcard("json_test_suite/*") do
    case Path.basename(path) do
      "y_" <> _ = name ->
        test name do
          parse!(File.read!(unquote(path)))
        end
      "n_" <> _ = name ->
        test name do
          assert_raise Antidote.ParseError, ~r"unexpected", fn ->
            parse!(File.read!(unquote(path)))
          end
        end
      "i_" <> _ = name ->
        cond do
          name in i_fails ->
            test name do
              assert_raise Antidote.ParseError, ~r"unexpected", fn ->
                parse!(File.read!(unquote(path)))
              end
            end
          name in i_succeeds ->
            test name do
              parse!(File.read!(unquote(path)))
            end
        end
    end
  end

  defp parse!(json) do
    Antidote.decode!(json)
  end
end
