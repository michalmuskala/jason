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
end

