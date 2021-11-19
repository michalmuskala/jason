defmodule Jason.OrderedObject do
  @behaviour Access

  defstruct map: %{}, ordered_keys: []

  def new(values) do
    {ordered_keys, _} = Enum.unzip(values)
    map = :maps.from_list(values)
    %__MODULE__{map: map, ordered_keys: ordered_keys}
  end

  @impl Access
  def fetch(%__MODULE__{map: map}, key) do
    Map.fetch(map, key)
  end

  @impl Access
  def get_and_update(%__MODULE__{map: map} = obj, key, function) do
    {value, new_data} = Map.get_and_update(map, key, function)
    {value, %{obj | map: new_data}}
  end

  @impl Access
  def pop(%__MODULE__{map: map, ordered_keys: ordered_keys}, key) do
    {value, new_data} = Map.pop(map, key)

    {value,
     %__MODULE__{
       map: new_data,
       ordered_keys: List.delete(ordered_keys, key)
     }}
  end
end

defimpl Enumerable, for: Jason.OrderedObject do
  def count(%{map: map}), do: Enumerable.Map.count(map)

  def member?(%{map: map}, value), do: Enumerable.Map.member?(map, value)

  def slice(%{map: map}), do: Enumerable.Map.slice(map)

  def reduce(obj, acc, fun) do
    Enumerable.List.reduce(as_pair_list(obj), acc, fun)
  end

  defp as_pair_list(%{map: map, ordered_keys: ordered_keys}) do
    Enum.map(ordered_keys, fn key -> {key, map[key]} end)
  end
end

defimpl Jason.Encoder, for: Jason.OrderedObject do
  def encode(obj, opts) do
    Enum.into(obj, [])
    |> Jason.Encode.keyword(opts)
  end
end
