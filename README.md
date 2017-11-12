# Antidote

A blazing fast JSON parser and generator.

The parser is usually twice as fast as `Poison` and only about 50% slower than
`jiffy` - which is implemented in C with NIFs. On some data, `Antidote` can even
outperform `jiffy`. With HiPE, `Antidote` consistently outperforms `jiffy` on
all inputs by 20-30%.

The generator is also usually twice as fast as `Poison` and uses less memory. It
is about 1.3 to 2.0 times slower than `jiffy` depending on input.
With HiPE `Antidote` is 1.3 to even 2.5 times faster than `jiffy`.

Both parser and generator fully conform to RFC 7159 and ECMA 404 standard.
The parser is tested using JSONTestSuite.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `antidote` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:antidote, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/antidote](https://hexdocs.pm/antidote).

## Use with other libraries

### Postgrex

You need to define a custom "types" module:

```elixir
Postgrex.Types.define(MyApp.PostgresTypes, [], json: Antidote)

## If using with ecto, you also need to pass ecto default extensions:

Postgrex.Types.define(MyApp.PostgresTypes, [] ++ Ecto.Adapters.Postgres.extensions(), json: Antidote)
```

Then you can use the module, by passing it to `Postgrex.start_link`.

### Ecto

To replicate fully the current behaviour of `Poison` when used in Ecto applications,
you need to configure `Antidote` to be the default encoder:

```elixir
config :ecto, json_library: Antidote
```

Additionally, when using PostgreSQL, you need to define a custom types module as described
above, and configure your repo to use it:

```elixir
config :my_app, MyApp.Repo, types: MyApp.PostgresTypes
```

### Plug (and Phoenix)

First, you need to configure `Plug.Parsers` to use `Antidote` for parsing JSON. You need to find,
where you're plugging the `Plug.Parsers` plug (in case of Phoenix, it will be in the
Endpoint module) and configure it, for example:

```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  json_decoder: Antidote
```

Additionally, for Phoenix, you need to configure the "encoder"

```elixir
config :phoenix, :format_encoders,
  json: Antidote
```

Unfortunately, it's not possible right now to configure the encoder and parser used in
channels.

### Absinthe

You need to pass the `:json_codec` option to `Absinthe.Plug`

```elixir
# When called directly:
plug Absinthe.Plug,
  schema: MyApp.Schema,
  json_codec: Antidote

# When used in phoenix router:
forward "/api",
  to: Absinthe.Plug,
  init_opts: [schema: MyApp.Schema, json_codec: Antidote]
```

## Benchmars

Benchmarks against most popular Elixir & Erlang json libraries can be executed
with `mix bench encode` and `mix bench decode`.
A HTML report of the benchmarks (after their execution) can be found in
`bench/output/encode.html` and `bench/output/decode.html` respectively.

## License

Antidote is released under the Apache 2.0 License - see the [LICENSE](LICENSE) file.

Some elements of tests and benchmakrs have their origins in the
[Poison library](https://github.com/devinus/poison) and were initially licensed under [CC0-1.0](https://creativecommons.org/publicdomain/zero/1.0/).
