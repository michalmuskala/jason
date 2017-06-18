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

## Benchmars

Benchmarks against most popular Elixir & Erlang json libraries can be executed
with `mix bench encode` and `mix bench decode`.
A HTML report of the benchmarks (after their execution) can be found in
`bench/output/encode.html` and `bench/output/decode.html` respectively.

# License

Antidote is released under the Apache 2.0 License - see the [LICENSE](LICENSE) file.

Some elements of tests and benchmakrs have their origins in the
[Poison library](https://github.com/devinus/poison) and were initially licensed under [CC0-1.0](https://creativecommons.org/publicdomain/zero/1.0/).
