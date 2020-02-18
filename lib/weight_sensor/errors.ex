defmodule Hx711Ex.WeightSensor.Errors do
  defmodule ReadTimeoutError do
    defexception message: "The reader timed out reading results"
  end

  defmodule ReadInProgressError do
    defexception message: "Read in progress"
  end

  defmodule ReadError do
    defexception [:message]
  end
end
