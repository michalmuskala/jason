defmodule Jason.OrderedObjectTest do
  use ExUnit.Case, async: true

  alias Jason.OrderedObject

  test "Access behavior" do
    obj = OrderedObject.new([{:foo, 1}, {"bar", 2}])

    assert obj[:foo] == 1
    assert obj["bar"] == 2

    assert Access.pop(obj, :foo) == {1, OrderedObject.new([{"bar", 2}])}

    obj = OrderedObject.new(foo: OrderedObject.new(bar: 1))
    assert obj[:foo][:bar] == 1
    modified_obj = put_in(obj[:foo][:bar], 2)
    assert %OrderedObject{} = modified_obj[:foo]
    assert modified_obj[:foo][:bar] == 2
  end

  test "Enumerable protocol" do
    obj = OrderedObject.new(foo: 1, bar: 2, quux: 42)

    assert Enum.count(obj) == 3
    assert Enum.member?(obj, {:foo, 1})

    assert Enum.into(obj, %{}) == %{foo: 1, bar: 2, quux: 42}
    assert Enum.into(obj, []) == [foo: 1, bar: 2, quux: 42]
  end
end
