defmodule Jason.FormatterTest do
  use ExUnit.Case, async: true
  import Jason.Formatter
  doctest Jason.Formatter

  @test_cases [
    "empty-list",
    "empty-object",
    "simple-list",
    "simple-object",
    "multiple-objects",
    "backslash-string",
    "empty-nest",
    "nested-maps"
  ]

  for name <- @test_cases do
    input = File.open!("formatter_test_suite/#{name}.json") |> IO.binread(:all)
    pretty = File.open!("formatter_test_suite/#{name}.pretty.json") |> IO.binread(:all)
    min = File.open!("formatter_test_suite/#{name}.min.json") |> IO.binread(:all)

    test "#{name} |> pretty_print" do
      assert(pretty_print(unquote(input)) == unquote(pretty))
    end

    test "#{name} |> minimize" do
      assert(minimize(unquote(input)) == unquote(min))
    end

    test "#{name} |> pretty_print |> pretty_print" do
      p = unquote(input) |> pretty_print |> pretty_print
      assert(p == unquote(pretty))
    end

    test "#{name} |> minimize |> minimize" do
      m = unquote(input) |> minimize |> minimize
      assert(m == unquote(min))
    end

    test "#{name} |> pretty_print |> minimize |> pretty_print" do
      p = unquote(input) |> pretty_print |> minimize |> pretty_print
      assert(p == unquote(pretty))
    end

    test "#{name} |> minimize |> pretty_print |> minimize" do
      m = unquote(input) |> minimize |> pretty_print |> minimize
      assert(m == unquote(min))
    end
  end

  test "pretty_print iolist" do
    input = [['{"a":', " 3.14159", []], [[44]], "\"b\":", '1}']
    output = ~s|{\n  "a": 3.14159,\n  "b": 1\n}|
    assert(pretty_print(input) == output)
  end

  test "minimize iolist" do
    input = [['{\n"a":  ', " 3.14159", []], [[44], '"'], "b\":\t", '1\n\n}']
    output = ~s|{"a":3.14159,"b":1}|
    assert(minimize(input) == output)
  end

  test "pretty_print indent string" do
    input = ~s|{"a": {"b": [true, false]}}|
    output = ~s|{\n\t"a": {\n\t\t"b": [\n\t\t\ttrue,\n\t\t\tfalse\n\t\t]\n\t}\n}|
    assert(pretty_print(input, indent: "\t") == output)
  end

  test "proper string escaping" do
    input = ["\"abc\\\\", "\""]
    output = ~S|"abc\\"|
    assert(minimize(input) == output)

    input = ["\"abc\\\\", ?"]
    output = ~S|"abc\\"|
    assert(minimize(input) == output)

    input = ["\"abc\\\"", "\""]
    output = ~S|"abc\""|
    assert(minimize(input) == output)

    input = ["\"abc\\\"", ?"]
    output = ~S|"abc\""|
    assert(minimize(input) == output)

    input = ["\"abc\\", "\"\""]
    output = ~S|"abc\""|
    assert(minimize(input) == output)

    input = ["\"abc\\", ?", ?"]
    output = ~S|"abc\""|
    assert(minimize(input) == output)

    input = ["\"abc", "\\", ?", ?"]
    output = ~S|"abc\""|
    assert(minimize(input) == output)

    input = ["\"abc\\", "\\", ?"]
    output = ~S|"abc\\"|
    assert(minimize(input) == output)

    input = ~s|["a\\\\"]|
    output = ~s|[\n  "a\\\\"\n]|
    assert(pretty_print(input) == output)
  end
end
