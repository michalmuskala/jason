defmodule Antidote.Mixfile do
  use Mix.Project

  def project do
    [
      app: :antidote,
      version: "0.1.0",
      elixir: "~> 1.4",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp deps do
    [
      {:decimal, "~> 1.0", optional: true},
      {:benchee, "~> 0.8", only: :bench},
      {:benchee_html, "~> 0.1", only: :bench},
      {:poison, "~> 3.0", only: :bench},
      {:exjsx, "~> 4.0", only: :bench},
      {:tiny, "~> 1.0", only: :bench},
      {:jsone, "~> 1.4", only: :bench},
      {:jiffy, "~> 0.14",  only: :bench},
      {:json, "~> 1.0", only: :bench}
    ]
  end

  defp aliases do
    ["bench": &bench/1]
  end

  defp bench(["encode"]) do
    {_, res} = System.cmd("mix", ~w(run bench/encode.exs),
      env: %{"MIX_ENV" => "bench"}, into: IO.stream(:stdio, :line))
    if res > 0 do
      System.at_exit(fn _ -> exit({:shutdown, res}) end)
    end
  end
  defp bench(["decode"]) do
    {_, res} = System.cmd("mix", ~w(run bench/decode.exs),
      env: %{"MIX_ENV" => "bench"}, into: IO.stream(:stdio, :line))
    if res > 0 do
      System.at_exit(fn _ -> exit({:shutdown, res}) end)
    end
  end
end
