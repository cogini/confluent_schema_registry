# confluent_schema_registry

Elixir client for the [Confluent Schema Registry](https://www.confluent.io/confluent-schema-registry).

It implements the full [REST API](https://docs.confluent.io/current/schema-registry/develop/api.html).

It uses the [Tesla](https://github.com/teamon/tesla) HTTP client library, and
so supports HTTP authentication, and other configuration flexibility, e.g.
selecting the underlying HTTP library (e.g. Hackney) and configuring it for
e.g. SSL.

It includes an ETS cache for results of schema lookups.

Thanks to [Schemex](https://hex.pm/packages/schemex).

## Usage

First create a client:

```elixir
client = ConfluentSchemaRegistry.client(base_url: "https://schemaregistry.example.com:8081/")
```

In the Kafka [wire format](https://docs.confluent.io/current/schema-registry/serializer-formatter.html#wire-format),
the data is prefixed by magic byte 0 to indicate that it is using the schema
registry, then four bytes for the schema id, then the data.

### Producer

On startup, a producer looks up the latest version of the schema matching the
"subject" associated with the topic it is writing on using `get_schema/3`.
It encodes the data to binary format using the schema, then appends the schema
id to the binary and sends it to Kafka.

```elixir
{:ok, result} = ConfluentSchemaRegistry.get_schema(client, "test", "latest")
schema = result["schema"]
schema_id = result["id"]
```

### Consumer

A consumer receives data, gets the schema id from the prefix, and looks it up
in the registry using `get_schema/1`, getting the schema which was used to write it.
It then decodes the binary using the schema.

```elixir
{:ok, schema} = ConfluentSchemaRegistry.get_schema(client, 21)
```

### Cache

In long running processes, the schema may be updated, and we should use the latest
version when writing data. The cache periodically contacts the registry to get
the latest version of the schema.

```elixir
{:ok, pid} = ConfluentSchemaRegistry.Cache.start_link([])
client = ConfluentSchemaRegistry.client()
{:ok, schema} = ConfluentSchemaRegistry.Cache.get_schema(client, 21)

```

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


## Configuration

If you are using the cache, add it to your application's supervision tree:

Add it to your supervision tree:

```elixir
children = [
  ConfluentSchemaRegistry.Cache
]

Supervisor.start_link(children, strategy: :one_for_one)
```

Configure the cache in `config/config.exs` or an environment specific file:

```elixir
config :confluent_schema_registry,
  :cache_ttl: 3600,
  :cache_refresh_cycle: 60
```

* `cache_ttl` - Time in seconds to cache lookups for "latest" schemas, default 3600
* `cache_refresh_cycle` - Time in seconds to check if latest values have changed


You can also configure [Tesla](https://hexdocs.pm/tesla/readme.html), e.g.:

```elixir
config :tesla, :adapter, Tesla.Adapter.Hackney
```
