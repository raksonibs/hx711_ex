defmodule Hx711Ex.WeightSensor do
  @moduledoc """
  Read the weight before and difference afterwards, compare if reader returned correctly

  {:ok, init_state} = Hx711Ex.WeightSensor.init([])

  {:ok, weight} = Hx711Ex.WeightSensor.read_raw_data_mean(init_state)
  """

  use GenServer

  alias Circuits.GPIO
  use Bitwise

  #  alias Hx711Ex.WeightSensor.Errors.ReadTimeoutError
  # alias Hx711Ex.WeightSensor.Errors.ReadError
  #  alias Hx711Ex.WeightSensor.Errors.ReadInProgressError

  @clk_pin 4
  @data_pin 24
  @sleep_time 1_000_000
  @read_timeout 2_000
  @readings_number 24
  @num_pulses 1

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
      num_pulses: 1,
      number_of_readings: 30
    ]
  end

  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def read(server, opts \\ []) do
    clk_pin = Keyword.get(opts, :clk_pin, @clk_pin)
    data_pin = Keyword.get(opts, :data_pin, @data_pin)
    GenServer.call(server, {:read, clk_pin, data_pin}, nil)
  end

  @impl GenServer
  def init(opts) do
    # set input/output pins
    clk_pin = Keyword.get(opts, :clk_pin, @clk_pin)
    data_pin = Keyword.get(opts, :data_pin, @data_pin)

    {:ok, clk_pin} = Circuits.GPIO.open(clk_pin, :output)
    {:ok, data_pin} = Circuits.GPIO.open(data_pin, :input)
    opts = Keyword.put_new(opts, :clk_pin, clk_pin)
    opts = Keyword.put_new(opts, :data_pin, data_pin)
    opts = Keyword.put_new(opts, :number_of_readings, @readings_number)
    opts = Keyword.put_new(opts, :number_of_pulses, @num_pulses)

    state = struct(State, opts)
    reset(state)

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:read, _timeout, _power}, _from, %{read_in_progress?: true} = state) do
    {:reply, {:error, :read_error}, state}
  end

  def handle_call({:read, clk_pin, data_pin}, from, state) do
    IO.inspect("clk_pin")
    IO.inspect(clk_pin)
    IO.inspect("data_pin")
    IO.inspect(data_pin)
    IO.inspect("state")
    IO.inspect(state)
    pid = self()
    ref = make_ref()

    spawn(fn -> send(pid, {:handle_weight, read_raw_data_mean(state), ref}) end)
    Process.send_after(self(), {:timeout, from}, @read_timeout)

    {:noreply, %{state | read_in_progress?: true, ref: ref}}
  end

  @impl GenServer
  def handle_info({:timeout, _from}, %{weight: nil} = state) do
    # GenServer.reply(from, {:error, %ReadTimeoutError{}})

    {:noreply, reset(state)}
  end

  @impl GenServer
  def handle_info({:timeout, from}, state) do
    weight = handle_weight(state.weight)
    GenServer.reply(from, weight)

    {:noreply, reset(state)}
  end

  def handle_info({:handle_weight, weight}, state) do
    IO.inspect("RESULT IS")
    IO.inspect(weight)
    weight = handle_weight(state.weight)
    # GenServer.reply(from, weight)
    {:noreply, %{state | weight: weight, read_in_progress?: false}}
  end

  @impl GenServer
  def handle_info({:handle_weight, weight, ref}, %{ref: ref} = state) do
    {:noreply, %{state | weight: weight}}
  end

  def handle_info({:handle_weight, _weight, _ref}, state) do
    {:noreply, state}
  end

  defp handle_weight({:ok, weight}) do
    {:ok, weight}
  end

  defp handle_weight(weight) do
    # {:error, %ReadError{}}
    {:error, weight}
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
    second_twos = -(data_in &&& 0x800000) + (data_in &&& 0x7FFFFF)
    converted = -((data_in ^^^ 0xFFFFFF) + 1)
    converted_two = -((data_in ^^^ 0x7FFFFF) + 1)
    IO.inspect("data_in")
    IO.inspect(data_in)
    IO.inspect("converted")
    IO.inspect(converted)
    IO.inspect("second_twos")
    IO.inspect(second_twos)
    IO.inspect("converted_two")
    IO.inspect(converted_two)
    converted
  end

  def read_raw_data(state) do
    # should link process to call this when ready
    wait_for_data_ready(state)

    data_in = 0
    # 24 is used in all instances, as number of bits in data, need to pad out and convert.
    0..24
    |> Enum.reduce(data_in, fn _item, acc ->
      set_clock_high_and_low(state)

      # Shift the bits as they come to data_in variable.
      # Left shift by one bit then bitwise OR with the new bit.
      IO.inspect("acc")
      IO.inspect(acc)
      read_data = read_pin(state.data_pin)
      IO.inspect("read_data")
      IO.inspect(read_data)
      left_shifted_data = acc <<< 2
      IO.inspect("left_shifted_data")
      IO.inspect(left_shifted_data)
      bitwised_or = left_shifted_data ||| read_data

      IO.inspect("bitwised_or")
      IO.inspect(bitwised_or)
      bitwised_or
    end)

    # need to repulse
    0..state.num_pulses
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
    IO.inspect("data_in after_twos_complement")
    IO.inspect(data_in)

    signed_data =
      case data_in &&& 0x800000 do
        true ->
          IO.inspect("converting in twos")
          convert_twos_complement_24_bit(data_in)

        _ ->
          IO.inspect("nonconverting in twos")
          data_in
      end

    IO.inspect("signed_data after_twos_complement")
    IO.inspect(signed_data)

    # {:ok, %{state | signed_data: signed_data}}
    {:ok, signed_data}
  end

  def read_raw_data_mean(state) do
    all_readings =
      0..state.number_of_readings
      |> Enum.reduce([], fn _reading, acc ->
        {:ok, signed_data} = read_raw_data(state)
        IO.inspect("signed_data read_raw_data_mean")
        IO.inspect(signed_data)
        acc ++ [signed_data]
      end)

    IO.inspect("all_readings")
    IO.inspect(all_readings)

    total =
      all_readings
      |> Enum.reduce(0, fn reading, acc ->
        acc + reading
      end)

    IO.inspect("total")
    IO.inspect(total)
    mean = total / (all_readings |> length())
    IO.inspect("mean")
    IO.inspect(mean)

    {:ok, mean}
  end

  def activate(pin) do
    GPIO.write(pin, 1)
  end

  def deactivate(pin) do
    GPIO.write(pin, 0)
  end

  def read_pin(pin) do
    GPIO.read(pin)
  end

  defp reset(state) do
    reset_hx(state)
    %{state | weight: nil, read_in_progress?: false, ref: nil}
  end
end
