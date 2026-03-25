defmodule Mix.Tasks.Bench.Decode do
  use Mix.Task
  @default_jobs [
    "Jason",
    "Poison",
    "JSX",
    "Tiny",
    "jsone",
    "jiffy",
    "JSON"
  ]

  @default_inputs [
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
             "Jason" -> {job, fn {json, _} -> Jason.decode!(json) end}
             "Poison" -> {job, fn {json, _} -> Poison.decode!(json) end}
             "JSX" -> {job, fn {json, _} -> JSX.decode!(json, [:strict]) end}
             "Tiny" -> {job, fn {json, _} -> Tiny.decode!(json) end}
             "jsone" -> {job, fn {json, _} -> :jsone.decode(json) end}
             "jiffy" -> {job, fn {json, _} -> :jiffy.decode(json, [:return_maps, :use_nil]) end}
             "JSON" -> {job, fn {json, _} -> JSON.decode!(json) end}
             "binary_to_term/1" -> {job, fn {_, etf} -> :erlang.binary_to_term(etf) end}
           end
         end
       ) |> Map.new()
  end

  defp inputs(args) do
    extract_values(args, :input, @default_inputs)
  end

  defp read_data(name) do
    file =
      name
      |> String.downcase
      |> String.replace(~r/([^\w]|-|_)+/, "-")
      |> String.trim("-")

    json = File.read!(Path.expand("../../../data/#{file}.json", __DIR__))
    etf = :erlang.term_to_binary(Jason.decode!(json))

    {json, etf}
  end

  defp benchee(args) do
    inputs = for name <- inputs(args), into: %{}, do: {name, read_data(name)}
    jobs = jobs(args)

    if args[:test] == nil or args[:text] == true do
      IO.puts("Checking jobs don't crash")
      for {name, input} <- inputs, {job, decode_job} <- jobs do
        IO.puts("Testing #{job} #{name}")
        decode_job.(input)
      end
      IO.puts("\n")
    end

    warmup = args[:warmup] || 5
    time = args[:time] || 30
    memory_time = args[:memory_time] || 1

    Benchee.run(jobs,
      #  parallel: 4,
      warmup: warmup,
      time: time,
      memory_time: memory_time,
      inputs: inputs,
      save: %{path: "../../../output/runs/#{DateTime.utc_now()}.benchee"},
      load: "../../../output/runs/*.benchee",
      formatters: [
        {Benchee.Formatters.HTML, file: Path.expand("../../../output/decode.html", __DIR__)},
        Benchee.Formatters.Console,
      ]
    )
  end


  def run(argv) do
    {args, _, _} = OptionParser.parse(
      argv,
      strict: [
        test: :boolean,
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
