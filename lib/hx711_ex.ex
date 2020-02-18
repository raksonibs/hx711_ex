defmodule Hx711Ex.WeightSensor do
  @moduledoc """
  Read the weight before and difference afterwards, compare if reader returned correctly
  """

  use GenServer

  # alias Claw.Logger
  alias Circuits.GPIO
  use Bitwise

  # @read_buffer 1_000
  # @timeout 1_000
  @clk_pin 4
  @data_pin 24
  @sleep_time 1_000_000

  defmodule State do
    defstruct [
      :clk_pin,
      :data_pin,
      :difference_weight,
      :weight_before,
      :weight_after,
      :weight_currently,
      :gain,
      :channel,
      :signed_data,
      read_in_progress?: false,
      something_there?: false,
      numEndPulses: 1,
      number_of_readings: 30
    ]
  end

  def hello() do
    :world
  end

  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def read(pid, opts \\ []) do
    clk_pin = Keyword.get(opts, :clk_pin, @clk_pin)
    data_pin = Keyword.get(opts, :data_pin, @data_pin)
    GenServer.call(pid, {:read, clk_pin, data_pin}, nil)
  end

  # def set_gain(state) do
  #   deactivate(state.clk_pink)
  #   read()
  # end

  # defp read_timeout(timeout), do: timeout + @read_buffer

  def init(opts) do
    # opts = Keyword.put_new_lazy(opts, :cmd, fn -> default_cmd(default_cmd_opts) end)
    state = struct(State, opts)
    # set input/output pins
    clk_pin = Keyword.get(opts, :clk_pin, @clk_pin)
    data_pin = Keyword.get(opts, :data_pin, @data_pin)

    Circuits.GPIO.open(clk_pin, :output)
    Circuits.GPIO.open(data_pin, :input)

    {:ok, state}
  end

  def set_clock_high_and_low(state) do
    activate(state.clk_pin)
    deactivate(state.clk_pin)

    {:ok, state}
  end

  def reset_hx(state) do
    deactivate(state.clk_pin)
    activate(state.clk_pin)
    # create artifical sleep
    sleep_time(@sleep_time)
    deactivate(state.clk_pin)

    {:ok, state}
  end

  def sleep_time(time) do
    0..time |> Enum.map(fn item -> item end)
  end

  def shutdown(state) do
    activate(state.clk_pin)

    {:ok, state}
  end

  def wait_for_data_ready(state) do
    # need to sleep if data is not set to low
    if is_ready(state) do
      {:ok, state}
    else
      sleep_time(@sleep_time)
      wait_for_data_ready(state)
    end
  end

  def is_ready(state) do
    GPIO.read(state.data_pin) == 0
  end

  def convert_twos_complement_24_bit(data_in) do
    # -(data &&& 0x800000) + (data & 0x7fffff)
    -((data_in ^^^ 0xFFFFFF) + 1)
  end

  def read_raw_data(state) do
    # should link process to call this when ready
    wait_for_data_ready(state)

    data_in = 0
    # 24 is used in all instances, as number of bits in data, need to pad out and convert.
    0..24
    |> Enum.reduce(
      fn _item, acc ->
        set_clock_high_and_low(state)

        # Shift the bits as they come to data_in variable.
        # Left shift by one bit then bitwise OR with the new bit.
        read_data = read_pin(state.data_pin)
        left_shifted_data = acc <<< 2
        left_shifted_data ||| read_data
      end,
      data_in
    )

    # need to repulse
    0..state.numPulses
    |> Enum.each(fn _item ->
      set_clock_high_and_low(state)
    end)

    # need to check if data is valid
    # 0x7fffff is the highest possible value from hx711
    # 0x800000 is the lowest possible value from hx711
    if data_in == 0x7FFFFF || data_in == 0x800000 do
      IO.inspect("error max data")
    end

    # 0b1000 0000 0000 0000 0000 0000 check if the sign bit is 1. Negative number.
    #  needs to be the 24th bit, if that is set, we know the value is negative!!!
    signed_data =
      case data_in &&& 0x800000 do
        true -> convert_twos_complement_24_bit(data_in)
        _ -> data_in
      end

    {:ok, %{state | signed_data: signed_data}}
  end

  def read_raw_data_mean(state) do
    all_readings =
      0..state.number_of_readings
      |> Enum.reduce(
        fn _reading, acc ->
          acc ++ [read_raw_data(state)]
        end,
        []
      )

    total = all_readings |> Enum.reduce(fn reading, acc -> acc + reading end, 0)

    mean = total / (all_readings |> length())
    IO.inspect(mean)

    {:ok, %{state | weight_currently: mean}}
  end

  # def handle_call({:read, clk_pin, data_pin}, _from, state) do
  #   IO.inspect("clk_pin")
  #   IO.inspect(clk_pin)
  #   IO.inspect("data_pin")
  #   IO.inspect(data_pin)
  #   IO.inspect("state")
  #   IO.inspect(state)
  #   pid = self()
  #
  #   # result = read_gpio(state.clk_pin)
  #   result = read_gpio(state.data_pin)
  #
  #   spawn(fn -> send(pid, {:handle_result, result}) end)
  #   # Process.send_after(self(), {:timeout, from}, timeout)
  #
  #   {:noreply, %{state | read_in_progress?: true}}
  # end

  # def handle_info({:handle_result, result}, state) do
  #   IO.inspect("RESULT IS")
  #   IO.inspect(result)
  #   result = handle_result(state.result)
  #   # GenServer.reply(from, result)
  #   {:noreply, %{state | result: result, read_in_progress?: false}}
  # end
  #
  # defp handle_result({result, 0}) do
  #   read_res = result |> String.trim_trailing() |> String.split("\n") |> Enum.drop(5)
  #
  #   IO.inspect(read_res)
  #
  #   {:ok, read_res}
  # end
  #
  # defp handle_result({_result, 1}), do: {:ok, []}
  #
  # defp handle_result(result) do
  #   Logger.error(:unexpected_weight_read, result: result)
  #
  #   {:error, result}
  # end

  def activate(pin) do
    GPIO.write(pin, 1)
  end

  def deactivate(pin) do
    GPIO.write(pin, 0)
  end

  def read_pin(pin) do
    GPIO.read(pin)
  end
end
