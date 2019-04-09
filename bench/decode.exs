decode_jobs = %{
  "Jason"  => fn {json, _} -> Jason.decode!(json) end,
  "Poison" => fn {json, _} -> Poison.decode!(json) end,
  "JSX"    => fn {json, _} -> JSX.decode!(json, [:strict]) end,
  "Tiny"   => fn {json, _} -> Tiny.decode!(json) end,
  "jsone"  => fn {json, _} -> :jsone.decode(json) end,
  "jiffy"  => fn {json, _} -> :jiffy.decode(json, [:return_maps, :use_nil]) end,
  "JSON"   => fn {json, _} -> JSON.decode!(json) end,
  # "binary_to_term/1" => fn {_, etf} -> :erlang.binary_to_term(etf) end,
}

decode_inputs = [
  "GitHub",
  "Giphy",
  "GovTrack",
  "Blockchain",
  "Pokedex",
  "JSON Generator",
  "JSON Generator (Pretty)",
  "UTF-8 escaped",
  "UTF-8 unescaped",
  "Issue 90",
]

read_data = fn (name) ->
  file =
    name
    |> String.downcase
    |> String.replace(~r/([^\w]|-|_)+/, "-")
    |> String.trim("-")

  json = File.read!(Path.expand("data/#{file}.json", __DIR__))
  etf = :erlang.term_to_binary(Jason.decode!(json))

  {json, etf}
end

inputs = for name <- decode_inputs, into: %{}, do: {name, read_data.(name)}

Benchee.run(decode_jobs,
#  parallel: 4,
  warmup: 5,
  time: 30,
  memory_time: 1,
  inputs: inputs,
  formatters: [
    {Benchee.Formatters.HTML, file: Path.expand("output/decode.html", __DIR__)},
    Benchee.Formatters.Console,
  ]
)
