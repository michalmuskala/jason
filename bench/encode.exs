encode_jobs = %{
  "Jason" => &Jason.encode_to_iodata!(&1, escape: :elixir_json),
  "Jason native" => &Jason.encode_to_iodata!(&1, escape: :native_json),
  # "Jason strict"   => &Jason.encode_to_iodata!(&1, maps: :strict, escape: :elixir_json),
  "Poison" => &Poison.encode!/1,
  # "JSX"            => &JSX.encode!/1,
  # "Tiny"           => &Tiny.encode!/1,
  # "jsone"          => &:jsone.encode/1,
  "jiffy" => &:jiffy.encode/1
  # "JSON"           => &JSON.encode!/1,
  # "term_to_binary" => &:erlang.term_to_binary/1,
}

encode_inputs = [
  "GitHub",
  "Giphy",
  "GovTrack",
  "Blockchain",
  "Pokedex",
  "JSON Generator",
  "JSON Generator atoms",
  "UTF-8 unescaped",
  "Issue 90",
  "Canada"
]

read_data = fn name ->
  trimmed = String.trim_trailing(name, " atoms")

  data =
    trimmed
    |> String.downcase()
    |> String.replace(~r/([^\w]|-|_)+/, "-")
    |> String.trim("-")
    |> (&"data/#{&1}.json").()
    |> Path.expand(__DIR__)
    |> File.read!()

  if name == trimmed do
    Jason.decode!(data)
  else
    Jason.decode!(data, keys: :atoms)
  end
end

Benchee.run(encode_jobs,
  #  parallel: 4,
  warmup: 1,
  time: 5,
  memory_time: 0.1,
  inputs:
    for name <- encode_inputs, into: %{} do
      {name, read_data.(name)}
    end,
  formatters: [
    {Benchee.Formatters.HTML, file: Path.expand("output/encode.html", __DIR__)},
    Benchee.Formatters.Console
  ]
)
