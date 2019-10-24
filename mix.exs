defmodule ConfluentSchemaRegistry.MixProject do
  use Mix.Project

  def project do
    [
      app: :confluent_schema_registry,
      version: "0.1.0",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      source_url: "https://github.com/cogini/confluent_schema_registry",
      homepage_url: "https://github.com/cogini/confluent_schema_registry",
      deps: deps(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger] ++ extra_applications(Mix.env())
    ]
  end

  defp extra_applications(:test), do: [:hackney]
  defp extra_applications(_),     do: []

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.19.2", only: :dev, runtime: false},
      {:tesla, "~> 1.3"},
      {:jason, "~> 1.0"},
      {:hackney, "~> 1.14", only: [:dev, :test]},
      {:dialyxir, "~> 0.5.1", only: [:dev, :test], runtime: false},
      {:telemetry, "~> 0.4.0"},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
  defp description do
    "Client for Confluent Schema Registry"
  end

  defp package do
    [
      maintainers: ["Jake Morrison"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/cogini/confluent_schema_registry"}
    ]
  end

  defp docs do
    [
      source_url: "https://github.com/cogini/confluent_schema_registry",
      extras: ["README.md"]
    ]
  end
end
