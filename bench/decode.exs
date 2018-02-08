json_decode_jobs = %{
  "Jason" => &Jason.decode!/1,
  "Poison"   => &Poison.decode!/1,
  "JSX"      => &JSX.decode!(&1, [:strict]),
  "Tiny"     => &Tiny.decode!/1,
  "jsone"    => &:jsone.decode/1,
  "jiffy"    => &:jiffy.decode(&1, [:return_maps, :use_nil]),
  "JSON"     => &JSON.decode!/1,
}

erlang_term_to_binary_decode_jobs = %{
  "binary_to_term/1" => &:erlang.binary_to_term/1,
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

read_json_data = fn (name) ->
  name
  |> String.downcase
  |> String.replace(~r/([^\w]|-|_)+/, "-")
  |> String.trim("-")
  |> (&"data/json/#{&1}.json").()
  |> Path.expand(__DIR__)
  |> File.read!
end

read_erlang_binary_data = fn (name) ->
  name
  |> String.downcase
  |> String.replace(~r/([^\w]|-|_)+/, "-")
  |> String.trim("-")
  |> (&"data/binary/#{&1}.binary").()
  |> Path.expand(__DIR__)
  |> File.read!
end

json_inputs =
  for name <- decode_inputs, into: %{} do
    name
    |> read_json_data.()
    |> (&{name, &1}).()
  end

json_benchmarks =
  for {input_name, input_data} <- json_inputs,
      {job_name, job_fn} <- json_decode_jobs,
      into: %{}
  do
    {input_name <> " " <> job_name, fn() -> job_fn.(input_data) end}
  end

erlang_binary_inputs =
  for name <- decode_inputs, into: %{} do
    name
    |> read_erlang_binary_data.()
    |> (&{name, &1}).()
  end

erlang_term_to_binary_benchmarks =
  for {input_name, input_data} <- erlang_binary_inputs,
      {job_name, job_fn} <- erlang_term_to_binary_decode_jobs,
      into: %{}
  do
    {input_name <> " " <> job_name, fn() -> job_fn.(input_data) end}
  end

all_benchmarks = Map.merge(json_benchmarks, erlang_term_to_binary_benchmarks)

Benchee.run(all_benchmarks,
  parallel: 4,
  warmup: 5,
  time: 30,
  formatters: [
    &Benchee.Formatters.HTML.output/1,
    &Benchee.Formatters.Console.output/1,
  ],
  formatter_options: [
    html: [
      file: Path.expand("output/decode.html", __DIR__)
    ]
  ]
)
