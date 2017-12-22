defmodule Jason.Mixfile do
  use Mix.Project

  def project do
    [
      app: :jason,
      version: "0.1.0",
      elixir: "~> 1.4",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env != :test,
      deps: deps(),
      aliases: aliases(),
      dialyzer: dialyzer()
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
      {:benchee, "~> 0.8", only: :dev},
      {:benchee_html, "~> 0.1", only: :dev},
      {:poison, "~> 3.0", only: :dev},
      {:exjsx, "~> 4.0", only: :dev},
      {:tiny, "~> 1.0", only: :dev},
      {:jsone, "~> 1.4", only: :dev},
      {:jiffy, "~> 0.14",  only: :dev},
      {:json, "~> 1.0", only: :dev},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false}
    ] ++ maybe_stream_data()
  end

  defp maybe_stream_data() do
    if Version.match?(System.version(), "~> 1.5") do
      [{:stream_data, "~> 0.4", only: :test}]
    else
      []
    end
  end

  defp aliases do
    [
      "bench.encode": ["run bench/encode.exs"],
      "bench.decode": ["run bench/decode.exs"]
    ]
  end

  defp dialyzer() do
    [
      plt_apps: [:kernel, :stdlib, :elixir, :decimal],
      ignore_warnings: "dialyzer.ignore"
    ]
  end
end
