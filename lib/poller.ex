defmodule Poller do
  @moduledoc """
    Module for continiously polling inputs
  """
  use GenServer

  @server_name :process_poller

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: @server_name)
  end

  def init(state) do
    init_pollers
    {:ok, state}
  end

  @doc """
  Spawns a function for each button that checks if button has been pushed. Also spawns a function that 
  checks if the elevator has reached a floor.
  """
  def init_pollers do
    button_map = Utils.get_all_buttons()
    Enum.map(button_map[:cab], fn x -> spawn(Poller, :button_check, [:off, x, :cab]) end)
    Enum.map(button_map[:up], fn x -> spawn(Poller, :button_check, [:off, x, :up]) end)
    Enum.map(button_map[:down], fn x -> spawn(Poller, :button_check, [:off, x, :down]) end)
    spawn(Poller, :floor_check, [:between_floors])
  end

  @doc """
    Checks for button presse. Sends the order to the Distro module if a button has been pressed. 
  """
  def button_check(:off, floor, type) do
    if 1 == ElevatorDriver.get_order_button_state(:process_driver, floor, type) do
      Distro.new_order(:process_distro, %Order{direction: type, floor: floor})
      button_check(:on, floor, type)
    end

    Process.sleep(100)
    button_check(:off, floor, type)
  end

  def button_check(:on, floor, type) do
    if 1 == ElevatorDriver.get_order_button_state(:process_driver, floor, type) do
      button_check(:on, floor, type)
    end

    Process.sleep(100)
    button_check(:off, floor, type)
  end

  @doc """
  Function to check if the elevator has arrived at a floor
  Creats a statemachine by taking in the atom :between_floors or :at_floor.
  When it arrives at a floor it will send a msg to the state machine to tell it which floor it has
  arrived at.
  """
  def floor_check(:between_floors) do
    floor = ElevatorDriver.get_floor_sensor_state(:process_driver)

    if !is_atom(floor) do
      # Arrived at floor. Call statemachin to tell it where it is.
      IO.puts(["Arrived at floor ", to_string(floor)])
      ElevatorState.arrived_at_floor(:process_elevator, floor)
      floor_check(:at_floor)
    end

    Process.sleep(20)
    floor_check(:between_floors)
  end

  def floor_check(:at_floor) do
    if is_atom(ElevatorDriver.get_floor_sensor_state(:process_driver)) do
      IO.puts(["Left floor"])
      floor_check(:between_floors)
    end

    Process.sleep(20)
    floor_check(:at_floor)
  end

  def print_button(floor, type) do
    IO.puts([Atom.to_string(type), " button has been pushed for floor ", to_string(floor)])
  end
end
