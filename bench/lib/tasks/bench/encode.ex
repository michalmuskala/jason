defmodule Mix.Tasks.Bench.Encode do
  use Mix.Task

  @default_jobs [
    "Jason",
    "Jason native",
    "Poison",
    "jiffy",
  ]

  @default_inputs [
    "GitHub",
    "Giphy",
    "GovTrack",
    "Blockchain",
    "Pokedex",
    "JSON Generator",
    "UTF-8 unescaped",
    "Issue 90",
    "Canada",
  ]


  defp extract_values(args, key, default \\ []) do
    Enum.map(
      args,
      fn arg ->
        case arg do
          {^key, input} -> input
          _ -> nil
        end
      end
    )
    |> Enum.reject(&is_nil/1)
    |> case do
         [] -> default
         x -> x
       end
  end

  defp jobs(args) do
    extract_values(args, :job, @default_jobs)
    |> Enum.map(
      fn(job) ->
        case job do
          "Jason" -> {job, &Jason.encode_to_iodata!(&1, escape: :elixir_json)}
          "Jason native" -> {job, &Jason.encode_to_iodata!(&1, escape: :native_json)}
          "Jason strict" -> {job, &Jason.encode_to_iodata!(&1, maps: :strict, escape: :elixir_json)}
          "Poison" -> {job, &Poison.encode!/1}
          "JSX" -> {job, &JSX.encode!/1}
          "Tiny" -> {job, &Tiny.encode!/1}
          "jsone" -> {job, &:jsone.encode/1}
          "jiffy" -> {job, &:jiffy.encode/1}
          "JSON" -> {job, &JSON.encode!/1}
          "term_to_binary" -> {job, &:erlang.term_to_binary/1}
        end
      end
    ) |> Map.new()
  end

  defp inputs(args) do
    extract_values(args, :input, @default_inputs)
  end

  defp read_data(name) do
    name
    |> String.downcase
    |> String.replace(~r/([^\w]|-|_)+/, "-")
    |> String.trim("-")
    |> (&"../../../data/#{&1}.json").()
    |> Path.expand(__DIR__)
    |> File.read!
  end

  defp benchee(args \\ nil)
  defp benchee(args) do
    warmup = args[:warmup] || 2
    time = args[:time] || 15
    memory_time = args[:memory_time] || 0.01
    reduction_time = args[:reduction_time] || 0.01

    encode_jobs = jobs(args)
    encode_inputs = inputs(args)
    Benchee.run(encode_jobs,
      #  parallel: 4,
      warmup: warmup,
      time: time,
      memory_time: memory_time,
      reduction_time: reduction_time,
      inputs: for name <- encode_inputs do
        name
        |> read_data()
        |> Jason.decode!()
        |> (&{name, &1}).()
      end,
      formatters: [
        {Benchee.Formatters.HTML, file: Path.expand("../../../output/encode.html", __DIR__)},
        Benchee.Formatters.Console
      ]
    )
  end

  def run(argv) do
    {args, _, _} = OptionParser.parse(
      argv,
      strict: [
        input: [:string,:keep],
        job: [:string,:keep],
        warmup: :integer,
        time: :integer,
        memory_time: :float,
        reduction_time: :float,
      ]
    )
    benchee(args)
  end

end
