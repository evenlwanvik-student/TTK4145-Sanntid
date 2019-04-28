defmodule ElevatorState do
  @moduledoc """
  This module keeps track of and handles the state of the elevator.
  The Genserver provides an API for outside functions to provide conditions for updating the state.
  """
  use GenServer
  @server_name :process_elevator
  # Max acceptable elevator timeout [sec]
  @elev_timeout_sec 6

  def start_link([]) do
    start_link(:ok, [{:name, @server_name}])
  end

  def start_link(type, opts) do
    GenServer.start_link(__MODULE__, type, opts)
  end

  @doc """
  Starts the elevator by finding a defined position. This is done by either starting at a floor or driving 
  upwards until the elevator reaches a floor. A watchdog is started in case of motor death. 
  """
  def init(:ok) do
    cond do
      is_atom(ElevatorDriver.get_floor_sensor_state(:process_driver)) ->
        ElevatorDriver.set_motor_direction(:process_driver, :motor_up)
        Process.spawn(fn -> elev_watchdog(:init) end, [])
        {:ok, %State{direction: :up, floor: 0}}

      true ->
        Process.spawn(fn -> idle_elevator() end, [])

        {:ok,
         %State{direction: :idle, floor: ElevatorDriver.get_floor_sensor_state(:process_driver)}}
    end
  end

  # ------------- API start

  @doc """
  Returns the current state from the server
  """
  def get_state(pid, node) do
    GenServer.call({pid, node}, :get_state)
  end

  @doc """
  Arrived at floor: Check if at_floor_orders, if any orders at this floor, serv them.
  Open door for three secounds at floor. 
  """
  def arrived_at_floor(pid, floor) do
    GenServer.cast(pid, {:arrived_at_floor, floor})
  end

  @doc """
  Routine for closing doors. Finds the next traveling direction for the elevator and removes served
  orders. Also starts a watchdog.
  """
  def close_doors(pid) do
    GenServer.cast(pid, {:close_doors})
  end

  @doc """
  Tells the Distro to re-distribute all the orders, and sets the state of the elevator to motor_dead
  """
  def motor_dead(pid) do
    GenServer.cast(pid, {:motor_dead})
  end

  @doc """
  Restarts the elevator.
  """
  def motor_alive(pid) do
    GenServer.cast(pid, {:motor_alive})
  end

  # ----------- Elevator watchdogs

  @doc """
  Watchdog to detect motor failure, counts 1 sec every recursive call, spawns when
  elevator starts running, and exits when floor is reached. If the state machine is running
  and the elevator haven't reached any floor within the timeout limit, tell other elevator that I'm dead,
  redistribute and start an new watchdog to check if elevator is back online.
  ## Examples
    1. Elevator starting to move upwards:
      iex> elev_watchdog :alive, :up, 0
  """
  defp elev_watchdog(:init) do
    state = get_state(:process_elevator, Node.self())
    elev_watchdog(:alive, state.direction, state.floor, 0)
  end

  @doc """
  Watchdog to detect motor failure, exits process if state of elevator has changed
  """
  defp elev_watchdog(:dead, prevDir, prevFloor) do
    Process.sleep(1000)
    state = get_state(:process_elevator, Node.self())

    if state.direction not in [prevDir, :motor_dead] or state.floor != prevFloor do
      IO.puts("Motor has revived")
      motor_alive(@server_name)
      Process.exit(self, :normal)
    else
      elev_watchdog(:dead, prevDir, prevFloor)
    end
  end

  @doc """
  Watchdog to detect if elevator is back online, back online if state of elevator has changed
  """
  defp elev_watchdog(:alive, prevDir, prevFloor, counter) do
    Process.sleep(1000)
    state = get_state(:process_elevator, Node.self())

    if state.direction not in [prevDir, :motor_dead] or state.floor != prevFloor do
      Process.exit(self, :normal)
    else
      if counter < @elev_timeout_sec do
        elev_watchdog(:alive, prevDir, prevFloor, counter + 1)
      else
        IO.puts("Motor died")
        motor_dead(@server_name)
        elev_watchdog(:dead, prevDir, prevFloor)
      end
    end
  end

  # ----------- Other functions

  def door_timer do
    Process.sleep(3000)
    close_doors(:process_elevator)
  end

  def idle_elevator do
    Process.sleep(100)

    cond do
      Distro.get_all_orders(:process_distro, Node.self())
      |> Enum.any?(fn x -> x.floor == get_state(:process_elevator, Node.self()).floor end) ->
        arrived_at_floor(:process_elevator, get_state(:process_elevator, Node.self()).floor)
        Process.exit(self, :normal)

      !Enum.empty?(Distro.get_all_orders(:process_distro, Node.self())) ->
        close_doors(:process_elevator)
        Process.exit(self, :normal)

      true ->
        :nothing
    end

    idle_elevator()
  end

  # --------- casts and calls

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:arrived_at_floor, floor}, state) do
    IO.puts(state.direction)

    cond do
      Distro.check_if_orders_at_floor(:process_distro, state.direction, floor) ->
        ElevatorDriver.set_motor_direction(:process_driver, :stop)
        ElevatorDriver.set_door_open_light(:process_driver, :on)
        IO.puts("Open door")

        Distro.remove_order(
          {:process_distro, Node.self()},
          %Order{direction: state.direction, floor: floor},
          Node.self()
        )

        Distro.remove_order(
          {:process_distro, Node.self()},
          %Order{direction: :cab, floor: floor},
          Node.self()
        )

        Process.spawn(fn -> door_timer() end, [])

        {:noreply, %{state | floor: floor}}

      Enum.empty?(Distro.get_all_orders(:process_distro, Node.self())) ->
        ElevatorDriver.set_motor_direction(:process_driver, :stop)
        Process.spawn(fn -> idle_elevator() end, [])
        {:noreply, %{state | direction: :idle, floor: floor}}

      true ->
        {:noreply, %{state | floor: floor}}
    end
  end

  @doc """
  Handles a cast from statemachine ...
  Spawns a watchdog to check if motor is online if the elevator is going to start move (:up, :down).
  """
  def handle_cast({:close_doors}, state) do
    ElevatorDriver.set_door_open_light(:process_driver, :off)

    case Distro.get_direction(:process_distro, state) do
      :up ->
        ElevatorDriver.set_motor_direction(:process_driver, :motor_up)

        Distro.remove_order(
          {:process_distro, Node.self()},
          %Order{direction: :up, floor: state.floor},
          Node.self()
        )

        Process.spawn(fn -> elev_watchdog(:init) end, [])
        {:noreply, %{state | direction: :up}}

      :down ->
        ElevatorDriver.set_motor_direction(:process_driver, :motor_down)

        Distro.remove_order(
          {:process_distro, Node.self()},
          %Order{direction: :down, floor: state.floor},
          Node.self()
        )

        Process.spawn(fn -> elev_watchdog(:init) end, [])
        {:noreply, %{state | direction: :down}}

      :none ->
        Distro.remove_order(
          {:process_distro, Node.self()},
          %Order{direction: :up, floor: state.floor},
          Node.self()
        )

        Distro.remove_order(
          {:process_distro, Node.self()},
          %Order{direction: :down, floor: state.floor},
          Node.self()
        )

        Distro.remove_order(
          {:process_distro, Node.self()},
          %Order{direction: :cab, floor: state.floor},
          Node.self()
        )

        Process.spawn(fn -> idle_elevator() end, [])
        {:noreply, %{state | direction: :idle}}
    end
  end

  def handle_cast({:motor_dead}, state) do
    Distro.flush_orders()
    {:noreply, %{state | direction: :motor_dead}}
  end

  @doc """
  Motor alive again, restart the state machine since every order has already been
  distributed to other nodes.
  """
  def handle_cast({:motor_alive}, state) do
    IO.puts("Restarting state machine")
    init(:ok)
    {:noreply, state}
  end

  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end
end
