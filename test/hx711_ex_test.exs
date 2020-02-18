defmodule Hx711ExTest do
  use ExUnit.Case
  doctest Hx711Ex.WeightSensor

  test "read_raw_data works" do
    {:ok, state} = Hx711Ex.WeightSensor.init([])

    assert {:ok, state} = Hx711Ex.WeightSensor.read_raw_data(state)
    assert 0
  end

  test "read_raw_data_mean works" do
    {:ok, init_state} = Hx711Ex.WeightSensor.init([])

    assert {:ok, weight} = Hx711Ex.WeightSensor.read_raw_data_mean(init_state)
    assert weight == 0

    # make clk turn on, give some data to input, not ready.
    Circuits.GPIO.write(init_state.clk_pin, 1)
    assert {:ok, weight} = Hx711Ex.WeightSensor.read_raw_data_mean(init_state)
    # tmp
    assert weight == 0
  end
end
