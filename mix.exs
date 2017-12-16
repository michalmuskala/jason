defmodule Antidote.Mixfile do
  use Mix.Project

  def project do
    [
      app: :antidote,
      version: "0.1.0",
      elixir: "~> 1.4",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env != :test,
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
      {:stream_data, "~> 0.4", obly: :test},
      {:benchee, "~> 0.8", only: :dev},
      {:benchee_html, "~> 0.1", only: :dev},
      {:poison, "~> 3.0", only: :dev},
      {:exjsx, "~> 4.0", only: :dev},
      {:tiny, "~> 1.0", only: :dev},
      {:jsone, "~> 1.4", only: :dev},
      {:jiffy, "~> 0.14",  only: :dev},
      {:json, "~> 1.0", only: :dev}
    ]
  end

  defp aliases do
    [
      "bench.encode": ["run bench/encode.exs"],
      "bench.decode": ["run bench/decode.exs"]
    ]
  end
end
