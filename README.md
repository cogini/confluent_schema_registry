# confluent_schema_registry

Elixir client for the [Confluent® Schema Registry](https://www.confluent.io/confluent-schema-registry).

It implements the full [REST API](https://docs.confluent.io/current/schema-registry/develop/api.html) using
the [Tesla](https://github.com/teamon/tesla) HTTP client library. This gives it support for
HTTP authentication, SSL/TLS and other configuration flexibility, e.g.
selecting the underlying HTTP library (e.g. Hackney).

Thanks to [Schemex](https://hex.pm/packages/schemex) and [Avrora](https://github.com/Strech/avrora)
for inspiration.

## Installation

Add `confluent_schema_registry` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:confluent_schema_registry, "~> 0.1.0"}]
end
```

Then run `mix deps.get` to fetch the new dependency.

Documentation is on [HexDocs](https://hexdocs.pm/confluent_schema_registry).
To generate a local copy, run `mix docs`.

### Optional dependencies

By default, Tesla uses the [httpc](http://erlang.org/doc/man/httpc.html) HTTP client
which comes with OTP. That library is pretty bare bones, and has issues with
e.g. validating SSL certificates, so I recommend using [hackney](https://hex.pm/packages/hackney).
Configure it as documented in [Tesla.Adapter.Hackney](https://hexdocs.pm/tesla/Tesla.Adapter.Hackney.html).

```elixir
config :tesla, :adapter, Tesla.Adapter.Hackney
```

[AvroSchema](https://github.com/cogini/avro_schema) provides convenience functions
to work  with Avro schemas, tag ids, encode/decode data, and cache results for performance
and reliablilty.

## Usage

First create a client:

```elixir
client = ConfluentSchemaRegistry.client(base_url: "https://schemaregistry.example.com:8081/")
```

In the Kafka [wire format](https://docs.confluent.io/current/schema-registry/serializer-formatter.html#wire-format),
the data is prefixed by magic byte 0 to indicate that it is using the schema
registry, then four bytes for the schema id, then the data.

### Producer

On startup, a producer looks up the version of the schema matching the
subject associated with the topic it is writing on. It encodes the data to
binary format using the schema, then appends the schema id to the binary and
sends it to Kafka.

There are a couple of different options for how to get the schema, depending
on the policy and permissions for updating schemas.

`is_registered/3` checks if a schema has already been registered under the
specified subject. If so, it returns the registration.

```elixir
 schema = "{\"type\":\"record\",\"name\":\"test\",\"fields\":[{\"name\":\"field1\",\"type\":\"string\"},{\"name\":\"field2\",\"type\":\"int\"}]}"
case ConfluentSchemaRegistry.is_registered(client, "test", schema) do
  {:ok, reg} ->
    # Found
    schema = reg["schema"]
    schema_id = reg["id"]
  {:error, 404, %{"error_code" => 40401}} ->
    # Subject not found
  {:error, 404, %{"error_code" => 40403}} ->
    # Schema not found
  {:error, code, reason} ->
    # Other error
end
```

If the schema hasn't been registered, then the producer can attempt to
register it using `register_schema/3`. If it is successful, it returns the
schema id. It can be called multiple times, and will return the same schema id.

```elixir
case ConfluentSchemaRegistry.register_schema(client, "test", schema) do
  {:ok, schema_id} ->
    # Already registered
  {:error, 409, reason} ->
    # Conflict -- Incompatible Avro schema
  {:error, 422, reason} ->
    # Unprocessable Entity, Invalid Avro schema
  {:error, code, reason} ->
    # Other error
end
```

Another option is to use `get_schema/3` to read the latest registered schema
for the subject. You might do this when schema registrations are manually managed.

```elixir
case ConfluentSchemaRegistry.get_schema(client, "test", "latest") do
  {:ok, reg} ->
    # Already registered
    schema = reg["schema"]
    schema_id = reg["id"]
  {:error, 404, %{"error_code" => 40401}} ->
    # Subject not found
  {:error, 404, %{"error_code" => 40402}} ->
    # Version not found
  {:error, 422, reason} ->
    # Unprocessable Entity, Invalid Avro version
  {:error, code, reason} ->
    # Other error
end
```

### Consumer

A consumer receives data, gets the schema id from the prefix, and looks it up
in the registry using `get_schema/1`, getting the schema which was used to write it.
It then decodes the binary using the schema.

```elixir
{:ok, schema} = ConfluentSchemaRegistry.get_schema(client, 21)
```

