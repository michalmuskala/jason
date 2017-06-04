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
      {:jiffy, "~> 0.14", only: :bench}
    ]
  end

  defp aliases do
    ["bench": "run bench/run.exs"]
  end
end
