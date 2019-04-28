defmodule Main do
  @moduledoc """
  This module is the main one, either called directly when starting the physical elevator, or indirectly by the Simulation node (below).
  The main purpose is to start a supervisor and initialize the child processes from it.
  """
  use Supervisor

  @strategy :one_for_one

  @doc """
  For running the actual elevator
  """
  def start :normal do
    Supervisor.start_link(__MODULE__, :normal, name: __MODULE__)
  end

  @doc """
  For simulation
  """
  def start mode, n \\ 1, elevator_number \\ 1 do
    Supervisor.start_link(__MODULE__, [mode, n, elevator_number], name: __MODULE__)
  end

  @doc """
  Normal project init
  """
  def init :normal do
    spawn(:os, :cmd, ['xterm -e ElevatorServer'])
    Process.sleep(1000)
    start_children :normal
    {:ok, :normal_evelator}
  end

  @doc """
  Simulation in Real-time lab init
  """ 
  def init [:simulation, n, elevator_number] do
    port = 20000 + elevator_number
    spawn(:os, :cmd, [
      'xterm -e "path to SimElevatorServer" --port #{port}'
    ])
    Process.sleep(1000)
    start_children :simulation, port
    {:ok, :simulation}
  end

  @doc """
  Normal procedure
  Starts all the child processes of the application sueprvisor. We maintain a simple one layered supervision tree, with "one for one" strategy, i.e. if a child process terminates, only that process is restarted.
  """   
  def start_children :normal do
    children = [
      ElevatorDriver,
      Poller,
      Network,
      Distro,
      ElevatorState
    ]

    Supervisor.init(children, strategy: @strategy)
    # other possible arguments for Supervisor.init:
    #    [max_restarts: :3 ], default 3
    #    [max_seconds: :3 ], default 5 (time frame of max restarts)
    #    [name: :3 ], default 3
  end

  @doc """
  Simulator procedure
  Starts all the child processes of the application sueprvisor. We maintain a simple one layered supervision tree, with "one for one" strategy, i.e. if a child process terminates, only that process is restarted.
  """   
  def start_children :simulation, port do
    ElevatorDriver.start_link port
    children = [
      #{ElevatorDriver, [port]},
      #Poller,
      #Distro,
      #ElevatorState
    ]

    Supervisor.init(children, strategy: @strategy)
    # other possible arguments for Supervisor.init:
    #    [max_restarts: :3 ], default 3
    #    [max_seconds: :3 ], default 5 (time frame of max restarts)
    #    [name: :3 ], default 3
  end
  
end

defmodule Simulation do
  @moduledoc """
  Only used for spawning n*2 xterm windows, one for each process and its elevator simulator.
  Each elevator will be named after their given port number, which starts at 12340 + elevatornumber,
  i.e. elev_number = 1, n = 2 -> port = 12341, 12342, ... 1234n.
  Run "$ epmd -daemon" if the Erlang network don't work properly.
  """

  def start mode \\ :simulation, n \\ 1, elevator_number \\1 do
    init_elevators mode, n, elevator_number
  end

  @doc """
  Init n elevators on a computer in the Real-time lab
  """
  def init_elevators :simulation, n, elevator_number do
    if elevator_number <= n do
      #spawn(:os, :cmd, ['xterm -hold -e iex -S mix run -e "Main.start :simulator, n, elevator_number"'])
      spawn(:os, :cmd, ['start iex -S mix run -e "Main.start :simulator, n, elevator_number"'])
      init_elevators(:simulation, n, elevator_number + 1)
    end
    {:ok, :init_simulation}
  end
end
