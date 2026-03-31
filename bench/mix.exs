defmodule JasonBench.MixProject do
  use Mix.Project

  def project do
    [
      app: :jason_bench,
      version: "0.1.0",
      elixir: "~> 1.6",
      elixirc_path: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  defp aliases() do
    [
      "bench.encode": ["run encode.exs"],
      "bench.decode": ["run decode.exs"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.0", path: "../", override: true},
      {:jason_native, ">= 0.0.0"},
      {:benchee, "~> 1.0"},
      {:benchee_html, "~> 1.0"},
      {:poison, "~> 5.0"},
      {:exjsx, "~> 4.0"},
      {:tiny, "~> 1.0"},
      {:jsone, "~> 1.4"},
      {:jiffy, "~> 1.0"},
      {:jsonrs, "~> 0.3"}
    ]
  end

  defp elixirc_paths(_), do: ["lib"]
end
