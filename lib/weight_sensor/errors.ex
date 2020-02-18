defmodule Hx711Ex.WeightSensor.Errors do
  defmodule ReadTimeoutError do
    defexception message: "The reader timed out reading results"
  end

  defmodule ReadError do
    defexception [:message]
  end
end
