# Hx711Ex

This is an elixir implementation of the Hx711 24-bit Analog to Digital Converter. It currently only outputs resistance values, non-normalized to any units or weights of measurement.

To use it, the interface is simple:

```
{:ok, init_state} = Hx711Ex.WeightSensor.init([clk_pin: 20, data_pin: 3])
{:ok, weight} = Hx711Ex.WeightSensor.read_raw_data_mean(init_state)

IO.inspect weight
 ```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `hx711_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hx711_ex, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/hx711_ex](https://hexdocs.pm/hx711_ex).

