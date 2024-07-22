defmodule ConfluentSchemaRegistry.MixProject do
  use Mix.Project

  @github "https://github.com/cogini/confluent_schema_registry"
  @version "0.1.1"

  def project do
    [
      app: :confluent_schema_registry,
      version: @version,
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      dialyzer: [
        plt_add_apps: [:mix, :eex]
        # flags: ["-Wunmatched_returns", :error_handling, :race_conditions, :underspecs]
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.lcov": :test,
        quality: :test,
        "quality.ci": :test
      ],
      description: description(),
      package: package(),
      source_url: @github,
      homepage_url: @github,
      docs: docs(),
      deps: deps()
    ]
  end

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
      {:castore, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18.0", only: [:dev, :test], runtime: false},
      {:hackney, "~> 1.14", only: [:dev, :test]},
      {:jason, "~> 1.0"},
      {:junit_formatter, "~> 3.3", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.0", only: [:dev, :test], runtime: false},
      {:styler, "~> 0.11.0", only: [:dev, :test], runtime: false},
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:tesla, "~> 1.11"}
    ]
  end

  defp description do
    "Client for Confluent Schema Registry"
  end

  defp package do
    [
      description: description(),
      maintainers: ["Jake Morrison"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github,
        "Changelog" => "#{@github}/blob/#{@version}/CHANGELOG.md##{String.replace(@version, ".", "")}"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @github,
      source_ref: @version,
      extras: [
        "README.md",
        "CHANGELOG.md": [title: "Changelog"],
        "LICENSE.md": [title: "License (Apache-2.0)"],
        "CONTRIBUTING.md": [title: "Contributing"],
        "CODE_OF_CONDUCT.md": [title: "Code of Conduct"]
      ],
      # api_reference: false,
      source_url_pattern: "#{@github}/blob/master/%{path}#L%{line}"
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      quality: [
        "test",
        "format --check-formatted",
        # "credo",
        "credo --mute-exit-status",
        # mix deps.clean --unlock --unused
        "deps.unlock --check-unused",
        # mix deps.update
        # "hex.outdated",
        # "hex.audit",
        "deps.audit",
        "dialyzer --quiet-with-result"
      ],
      "quality.ci": [
        "format --check-formatted",
        "deps.unlock --check-unused",
        # "hex.outdated",
        "hex.audit",
        "deps.audit",
        "credo",
        "dialyzer --quiet-with-result"
      ]
    ]
  end
end
