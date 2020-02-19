defmodule Hx711ExTest do
  use ExUnit.Case
  alias Hx711Ex.WeightSensor
  doctest Hx711Ex.WeightSensor

  describe "read_data" do
    test "read_raw_data works" do
      {:ok, state} = WeightSensor.init([])

      assert {:ok, state} = WeightSensor.read_raw_data(state)
      assert 0
    end

    test "read_raw_data_mean works" do
      {:ok, init_state} = WeightSensor.init([])

      assert {:ok, weight} = WeightSensor.read_raw_data_mean(init_state)
      assert weight == 0

      # make clk turn on, give some data to input, not ready.
      Circuits.GPIO.write(init_state.clk_pin, 1)
      assert {:ok, weight} = WeightSensor.read_raw_data_mean(init_state)
      # tmp
      assert weight == 0
    end
  end

  describe "gen_server" do
    setup do
      weight_sensor = start_supervised!(WeightSensor)
      %{weight_sensor: weight_sensor}
    end

    test "full genserver works", %{weight_sensor: weight_sensor} do
      result = WeightSensor.read(weight_sensor)
      assert result.weight_before == 0
      assert result.weight_currently == 0.0
      assert !result.something_there?
    end
  end
end
