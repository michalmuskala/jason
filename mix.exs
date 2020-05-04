defmodule Jason.Mixfile do
  use Mix.Project

  @version "1.2.1"

  def project() do
    [
      app: :jason,
      version: @version,
      elixir: "~> 1.4",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      preferred_cli_env: [docs: :docs],
      dialyzer: dialyzer(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def application() do
    [
      extra_applications: []
    ]
  end

  defp deps() do
    [
      {:decimal, "~> 1.0", optional: true},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.18", only: :docs},
    ] ++ maybe_stream_data()
  end

  defp maybe_stream_data() do
    if Version.match?(System.version(), "~> 1.5") do
      [{:stream_data, "~> 0.4", only: :test}]
    else
      []
    end
  end

  defp dialyzer() do
    [
      ignore_warnings: "dialyzer.ignore"
    ]
  end

  defp description() do
    """
    A blazing fast JSON parser and generator in pure Elixir.
    """
  end

  defp package() do
    [
      maintainers: ["Michał Muskała"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/michalmuskala/jason"}
    ]
  end

  defp docs() do
    [
      main: "readme",
      name: "Jason",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/jason",
      source_url: "https://github.com/michalmuskala/jason",
      extras: [
        "README.md"
      ]
    ]
  end
end
