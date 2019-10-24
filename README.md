# confluent_schema_registry

Elixir client for the [Confluent Schema Registry](https://www.confluent.io/confluent-schema-registry).

It implements the full [REST API](https://docs.confluent.io/current/schema-registry/develop/api.html).

It uses the [Tesla](https://github.com/teamon/tesla) HTTP client library, and so supports
HTTP authentication, and other configuration flexibility, e.g. selecting the underlying HTTP library (e.g. Hackney)
and configuring it for e.g. SSL.

It includes an ETS cache for results of schema lookups.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `confluent_schema_registry` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:confluent_schema_registry, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/confluent_schema_registry](https://hexdocs.pm/confluent_schema_registry).
