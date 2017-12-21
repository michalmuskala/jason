defmodule Jason.JsonTestSuite do
  use ExUnit.Case, async: true

  alias Jason.DecodeError

  # Implementation-dependent tests
  i_succeeds = [
    "number_double_huge_neg_exp.json",
    "number_real_underflow.json",
    "number_too_big_neg_int.json",
    "number_too_big_pos_int.json",
    "number_very_big_negative_int.json",
    "structure_500_nested_arrays.json",
  ]
  i_fails = [
    "number_huge_exp.json",
    "number_neg_int_huge_exp.json",
    "number_pos_double_huge_exp.json",
    "number_real_neg_overflow.json",
    "number_real_pos_overflow.json",
    "object_key_lone_2nd_surrogate.json",
    "string_1st_surrogate_but_2nd_missing.json",
    "string_1st_valid_surrogate_2nd_invalid.json",
    "string_UTF-16LE_with_BOM.json",
    "string_UTF-8_invalid_sequence.json",
    "string_UTF8_surrogate_U+D800.json",
    "string_incomplete_surrogate_and_escape_valid.json",
    "string_incomplete_surrogate_pair.json",
    "string_incomplete_surrogates_escape_valid.json",
    "string_invalid_lonely_surrogate.json",
    "string_invalid_surrogate.json",
    "string_invalid_utf-8.json",
    "string_inverted_surrogates_U+1D11E.json",
    "string_iso_latin_1.json",
    "string_lone_second_surrogate.json",
    "string_lone_utf8_continuation_byte.json",
    "string_not_in_unicode_range.json",
    "string_overlong_sequence_2_bytes.json",
    "string_overlong_sequence_6_bytes.json",
    "string_overlong_sequence_6_bytes_null.json",
    "string_truncated-utf-8.json",
    "string_utf16BE_no_BOM.json",
    "string_utf16LE_no_BOM.json",
    "structure_UTF-8_BOM_empty_object.json",
  ]

  for path <- Path.wildcard("json_test_suite/*") do
    case Path.basename(path) do
      "y_" <> name ->
        test name do
          Jason.decode!(File.read!(unquote(path)))
        end
      "n_" <> name ->
        test name do
          assert_raise DecodeError, ~r"unexpected", fn ->
            Jason.decode!(File.read!(unquote(path)))
          end
        end
      "i_" <> name ->
        cond do
          name in i_fails ->
            test name do
              assert_raise DecodeError, ~r"unexpected", fn ->
                Jason.decode!(File.read!(unquote(path)))
              end
            end
          name in i_succeeds ->
            test name do
              Jason.decode!(File.read!(unquote(path)))
            end
        end
    end
  end
end
