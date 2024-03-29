defmodule ConfluentSchemaRegistry.MixProject do
  use Mix.Project

  @github "https://github.com/cogini/confluent_schema_registry"

  def project do
    [
      app: :confluent_schema_registry,
      version: "0.1.1",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      source_url: @github,
      homepage_url: @github,
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        # plt_add_apps: [:erlavro, :tesla],
        # plt_add_deps: true,
        # flags: ["-Werror_handling", "-Wrace_conditions"],
        flags: ["-Wunmatched_returns", :error_handling, :race_conditions, :underspecs]
        # ignore_warnings: "dialyzer.ignore-warnings"
      ],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger] ++ extra_applications(Mix.env())
    ]
  end

  defp extra_applications(:test), do: [:hackney]
  defp extra_applications(_), do: []

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:excoveralls, "~> 0.12.0", only: [:dev, :test], runtime: false},
      {:hackney, "~> 1.14", only: [:dev, :test]},
      {:jason, "~> 1.0"},
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:tesla, "~> 1.3"}
    ]
  end

  defp description do
    "Client for Confluent Schema Registry"
  end

  defp package do
    [
      maintainers: ["Jake Morrison"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @github}
    ]
  end

  defp docs do
    [
      source_url: @github,
      extras: ["README.md", "CHANGELOG.md"],
      # api_reference: false,
      source_url_pattern: "#{@github}/blob/master/%{path}#L%{line}"
    ]
  end
end
