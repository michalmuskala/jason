encode_jobs =
  %{
    "Jason" => &Jason.encode_to_iodata!(&1, escape: :elixir_json),
    "Jason native" => &Jason.encode_to_iodata!(&1, escape: :native_json),
    # "Jason strict"   => &Jason.encode_to_iodata!(&1, maps: :strict, escape: :elixir_json),
    "Poison" => &Poison.encode!/1,
    # "JSX"            => &JSX.encode!/1,
    # "Tiny"           => &Tiny.encode!/1,
    # "jsone"          => &:jsone.encode/1,
    "jiffy" => &:jiffy.encode/1,
    "Jsonrs" => &Jsonrs.encode_to_iodata!/1,
    "Jsonrs (lean)" => &Jsonrs.encode_to_iodata!(&1, lean: true)
    # "term_to_binary" => &:erlang.term_to_binary/1,
  }
  |> Bench.Helpers.put_job_if_loaded(:json, &:json.encode/1)
  |> Bench.Helpers.put_job_if_loaded(Elixir.JSON, &Elixir.JSON.encode!/1)

encode_inputs = [
  "GitHub",
  "Giphy",
  "GovTrack",
  "Blockchain",
  "Pokedex",
  "JSON Generator",
  "UTF-8 unescaped",
  "Issue 90",
  "Canada"
]

Benchee.run(encode_jobs,
  #  parallel: 4,
  warmup: 2,
  time: 15,
  memory_time: 0.01,
  reduction_time: 0.01,
  pre_check: true,
  inputs:
    for name <- encode_inputs, into: %{} do
      name
      |> Bench.Helpers.read_data!()
      |> Jason.decode!()
      |> (&{name, &1}).()
    end,
  formatters: [
    {Benchee.Formatters.HTML, file: Path.expand("output/encode.html", __DIR__)},
    Benchee.Formatters.Console
  ]
)
