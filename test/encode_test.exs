defmodule Jason.EncoderTest do
  use ExUnit.Case, async: true

  alias Jason.{EncodeError, Encoder}

  test "atom" do
    assert to_json(nil) == "null"
    assert to_json(true) == "true"
    assert to_json(false) == "false"
    assert to_json(:poison) == ~s("poison")
  end

  test "integer" do
    assert to_json(42) == "42"
  end

  test "float" do
    assert to_json(99.99) == "99.99"
    assert to_json(9.9e100) == "9.9e100"
  end

  test "binaries" do
    assert to_json("hello world") == ~s("hello world")
    assert to_json("hello\nworld") == ~s("hello\\nworld")
    assert to_json("\nhello\nworld\n") == ~s("\\nhello\\nworld\\n")

    assert to_json("\"") == ~s("\\"")
    assert to_json("\0") == ~s("\\u0000")
    assert to_json(<<31>>) == ~s("\\u001F")
    assert to_json("☃a", escape: :unicode_safe) == ~s("\\u2603a")
    assert to_json("𝄞b", escape: :unicode_safe) == ~s("\\uD834\\uDD1Eb")
    assert to_json("\u2028\u2029abc", escape: :javascript_safe) == ~s("\\u2028\\u2029abc")
    assert to_json("</script>", escape: :html_safe) == ~s("\\u003C\\/script>")
    assert to_json(~s(<script>var s = "\u2028\u2029";</script>), escape: :html_safe) == ~s("\\u003Cscript>var s = \\\"\\u2028\\u2029\\\";\\u003C\\/script>")
    assert to_json("<!-- fake comment", escape: :html_safe) == ~s("\\u003C!-- fake comment")
    assert to_json("áéíóúàèìòùâêîôûãẽĩõũ") == ~s("áéíóúàèìòùâêîôûãẽĩõũ")
    assert to_json("a\u2028a", escape: :javascript_safe) == ~s("a\\u2028a")
    assert to_json("a\u2028a", escape: :html_safe) == ~s("a\\u2028a")

    assert_raise Protocol.UndefinedError, fn ->
      to_json(<<0::1>>)
    end

    # Poison-compatible escape options
    assert to_json("a\u2028a", escape: :javascript) == ~s("a\\u2028a")
    assert to_json("☃a", escape: :unicode) == ~s("\\u2603a")
  end

  test "Map" do
    assert to_json(%{}) == "{}"
    assert to_json(%{"foo" => "bar"})  == ~s({"foo":"bar"})
    assert to_json(%{foo: :bar}) == ~s({"foo":"bar"})
    assert to_json(%{42 => :bar}) == ~s({"42":"bar"})
    assert to_json(%{~c'foo' => :bar}) == ~s({"foo":"bar"})

    multi_key_map = %{"foo" => "foo1", :foo => "foo2"}
    assert_raise EncodeError, "duplicate key: foo", fn ->
      to_json(multi_key_map, maps: :strict)
    end

    assert to_json(multi_key_map) == ~s({"foo":"foo2","foo":"foo1"})
  end

  test "list" do
    assert to_json([]) == "[]"
    assert to_json([1, 2, 3]) == "[1,2,3]"
  end

  test "Time" do
    {:ok, time} = Time.new(12, 13, 14)
    assert to_json(time) == ~s("12:13:14")
  end

  test "Date" do
    {:ok, date} = Date.new(2000, 1, 1)
    assert to_json(date) == ~s("2000-01-01")
  end

  test "NaiveDateTime" do
    {:ok, datetime} = NaiveDateTime.new(2000, 1, 1, 12, 13, 14)
    assert to_json(datetime) == ~s("2000-01-01T12:13:14")
  end

  test "DateTime" do
    datetime = %DateTime{year: 2000, month: 1, day: 1, hour: 12, minute: 13, second: 14,
                         microsecond: {0, 0}, zone_abbr: "CET", time_zone: "Europe/Warsaw",
                         std_offset: -1800, utc_offset: 3600}
    assert to_json(datetime) == ~s("2000-01-01T12:13:14+00:30")

    datetime = %DateTime{year: 2000, month: 1, day: 1, hour: 12, minute: 13, second: 14,
                         microsecond: {50000, 3}, zone_abbr: "UTC", time_zone: "Etc/UTC",
                         std_offset: 0, utc_offset: 0}
    assert to_json(datetime) == ~s("2000-01-01T12:13:14.050Z")
  end

  test "Decimal" do
    decimal = Decimal.new("1.0")
    assert to_json(decimal) == ~s("1.0")
  end

  test "OrderedObject" do
    import Jason.OrderedObject, only: [new: 1]

    assert to_json(new([])) == "{}"
    assert to_json(new([{"foo", "bar"}]))  == ~s({"foo":"bar"})
    assert to_json(new([foo: :bar])) == ~s({"foo":"bar"})
    assert to_json(new([{42, :bar}])) == ~s({"42":"bar"})
    assert to_json(new([{~c'foo', :bar}])) == ~s({"foo":"bar"})

    multi_key_map = new([{"foo", "foo1"}, {:foo, "foo2"}])
    assert_raise EncodeError, "duplicate key: foo", fn ->
      to_json(multi_key_map, maps: :strict)
    end

    assert to_json(multi_key_map) == ~s({"foo":"foo1","foo":"foo2"})
  end

  test "Fragment" do
    pre_encoded_json = Jason.encode!(%{hello: "world", test: 123})
    assert to_json(%{foo: Jason.Fragment.new(pre_encoded_json)}) == ~s({"foo":#{pre_encoded_json}})
  end

  defmodule Derived do
    @derive Encoder
    defstruct name: ""
  end

  defmodule DerivedUsingOnly do
    @derive {Encoder, only: [:name]}
    defstruct name: "", size: 0
  end

  defmodule DerivedUsingExcept do
    @derive {Encoder, except: [:name]}
    defstruct name: "", size: 0
  end

  defmodule DerivedWeirdKey do
    @derive Encoder
    defstruct [:_]
  end

  defmodule NonDerived do
    defstruct name: ""
  end

  test "@derive" do
    derived = %Derived{name: "derived"}
    assert Encoder.impl_for!(derived) == Encoder.Jason.EncoderTest.Derived
    assert Jason.decode!(to_json(derived)) == %{"name" => "derived"}

    non_derived = %NonDerived{name: "non-derived"}
    assert_raise Protocol.UndefinedError, fn ->
      to_json(non_derived)
    end

    derived_using_only = %DerivedUsingOnly{name: "derived using :only", size: 10}
    assert to_json(derived_using_only) == ~s({"name":"derived using :only"})

    derived_using_except = %DerivedUsingExcept{name: "derived using :except", size: 10}
    assert to_json(derived_using_except) == ~s({"size":10})

    derived_weird_key = %DerivedWeirdKey{}
    assert to_json(derived_weird_key) == ~s({"_":null})
  end

  test "@derive validate `except:`" do
    message = "`:except` specified keys ([:invalid]) that are not defined in defstruct: [:name]"

    assert_raise ArgumentError, message, fn ->
      Code.eval_string("""
      defmodule InvalidExceptField do
        @derive {Jason.Encoder, except: [:invalid]}
        defstruct name: ""
      end
      """)
    end
  end

  test "@derive validate `only:`" do
    message = "`:only` specified keys ([:invalid]) that are not defined in defstruct: [:name]"

    assert_raise ArgumentError, message, fn ->
      Code.eval_string("""
      defmodule InvalidOnlyField do
        @derive {Jason.Encoder, only: [:invalid]}
        defstruct name: ""
      end
      """)
    end
  end

  defmodule KeywordTester do
    defstruct [:baz, :foo, :quux]
  end

  defimpl Jason.Encoder, for: [KeywordTester] do
    def encode(struct, opts) do
      struct
      |> Map.from_struct
      |> Enum.sort_by(&elem(&1, 0))
      |> Jason.Encode.keyword(opts)
    end
  end

  test "using keyword list encoding" do
    t = %KeywordTester{baz: :bar, foo: "bag", quux: 42}
    assert to_json(t) == ~s({"baz":"bar","foo":"bag","quux":42})
  end

  test "EncodeError" do
    assert_raise Protocol.UndefinedError, fn ->
      to_json(self())
    end

    assert_raise EncodeError, "invalid byte 0x80 in <<128>>", fn ->
      assert to_json(<<0x80>>, escape: :native_json)
    end

    assert_raise EncodeError, "invalid byte 0x80 in <<128>>", fn ->
      assert to_json(<<0x80>>, escape: :elixir_json)
    end

    assert_raise EncodeError, fn ->
      assert to_json(<<?a, 208>>, escape: :native_json)
    end

    assert_raise EncodeError, fn ->
      assert to_json(<<?a, 208>>, escape: :elixir_json)
    end
  end

  test "encode should not raise on Protocol.UndefinedError" do
    assert {:error, %Protocol.UndefinedError{}} = Jason.encode(self())
  end

  test "pretty: true" do
    object = Jason.OrderedObject.new(a: 3.14159, b: 1)
    assert to_json(object, pretty: true) == ~s|{\n  "a": 3.14159,\n  "b": 1\n}|
  end

  test "pretty: false" do
    object = Jason.OrderedObject.new(a: 3.14159, b: 1)
    assert to_json(object, pretty: false) == ~s|{"a":3.14159,"b":1}|
  end

  defp to_json(value) do
    native = Jason.encode!(value, escape: :native_json)
    elixir = Jason.encode!(value, escape: :elixir_json)
    assert native == elixir
    native
  end

  defp to_json(value, opts) do
    Jason.encode!(value, opts)
  end
end
