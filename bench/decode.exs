decode_jobs =
  %{
    "Jason" => &Jason.decode!/1,
    "Poison" => &Poison.decode!/1,
    "JSX" => &JSX.decode!(&1, [:strict]),
    "Tiny" => &Tiny.decode!/1,
    "jsone" => &:jsone.decode/1,
    "jiffy" => &:jiffy.decode(&1, [:return_maps, :use_nil]),
    "Jsonrs" => &Jsonrs.decode!/1
    # "binary_to_term/1" => fn {_, etf} -> :erlang.binary_to_term(etf) end,
  }
  |> Bench.Helpers.put_job_if_loaded(:json, &:json.decode/1)
  |> Bench.Helpers.put_job_if_loaded(Elixir.JSON, &Elixir.JSON.decode!/1)

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
  "Issue 90"
]

inputs = for name <- decode_inputs, into: %{}, do: {name, Bench.Helpers.read_data!(name)}

Benchee.run(decode_jobs,
  #  parallel: 4,
  warmup: 5,
  time: 30,
  memory_time: 1,
  pre_check: true,
  inputs: inputs,
  save: %{path: "output/runs/#{DateTime.utc_now()}.benchee"},
  load: "output/runs/*.benchee",
  formatters: [
    {Benchee.Formatters.HTML, file: Path.expand("output/decode.html", __DIR__)},
    Benchee.Formatters.Console
  ]
)
