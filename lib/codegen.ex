defmodule Antidote.Codegen do
  def jump_table(ranges, default) do
    ranges
    |> ranges_to_orddict()
    |> :array.from_orddict(default)
    |> :array.to_orddict()
  end

  def jump_table(ranges, default, max) do
    ranges
    |> ranges_to_orddict()
    |> :array.from_orddict(default)
    |> resize(max)
    |> :array.to_orddict()
  end

  defp resize(array, size), do: :array.resize(size, array)

  defp ranges_to_orddict(ranges) do
    ranges
    |> Enum.flat_map(fn
      {int, value} when is_integer(int) ->
        [{int, value}]
      {enum, value} ->
        Enum.map(enum, &{&1, value})
    end)
    |> :orddict.from_list()
  end
end
