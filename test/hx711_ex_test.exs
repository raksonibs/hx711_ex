defmodule Hx711ExTest do
  use ExUnit.Case
  doctest Hx711Ex.WeightSensor

  test "greets the world" do
    assert Hx711Ex.WeightSensor.hello() == :world
  end
end
