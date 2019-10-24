# confluent_schema_registry

Elixir client for the [Confluent Schema Registry](https://www.confluent.io/confluent-schema-registry).

It implements the full [REST API](https://docs.confluent.io/current/schema-registry/develop/api.html).

It uses the [Tesla](https://github.com/teamon/tesla) HTTP client library, and so supports
HTTP authentication, and other configuration flexibility, e.g. selecting the underlying HTTP library (e.g. Hackney)
and configuring it for e.g. SSL.

It includes an ETS cache for results of schema lookups.

## Installation

Add `confluent_schema_registry` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:confluent_schema_registry, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/confluent_schema_registry](https://hexdocs.pm/confluent_schema_registry).

## Usage

First create a client:

```elixir
client = ConfluentSchemaRegistry.client(base_url: "https://registry.example.com:8081/")
```

When writing Kafka clients, you mainly use `get_schema/1` or `get_schema/3`.

On startup, the produer looks up the latest version of the schema matching the "subject" associated
with the topic it is writing on. It then uses the schema to encode the


### Cache

```elixir
{:ok, pid} = ConfluentSchemaRegistry.Cache.start_link([])
client = ConfluentSchemaRegistry.client()
{:ok, schema} = ConfluentSchemaRegistry.Cache.get_schema(client, 21)

```

```elixir
config :tesla, Tesla.Middleware.Logger, debug: false,
  filter_headers: ["authorization"]

config :tesla, :adapter, Tesla.Adapter.Hackney

```
