# Project

Elevator Project in TTK4145 Real-time Programming written in Elixir.

[Project spesification](https://github.com/TTK4145/Project)

## Module introductions

The elevator consist mainly consist of six modules, and two helper moduler. These are the supervisor, Main, the elevator statemachine, ElevatorState, the networks module, Network, the distributor of orders, Distro, the pollers, Poller, and the driver for the elevator, ElevatorDriver. The helpers are Utils and NetworkUtils. 

Main: Handles the initilization and supervising of the other modules. It restarts them at the previous state if they crash.

ElevatorState: Keeps track of the elevator through the ElevatorDriver module. Keeps state as a floor number and a traveling direction or idle.

Network: Establishes conection to other nodes on the network thorough UDP. This is done by brodcasting its node name. 

Distro: Keeps track of all orders for all elevators on the network. These are kept as state in the GenServer. Gets new orders from the pollers. Also calculates which elevator is best able to handle new orders. 

Poller: Routinly check the buttons on the elevator and updates the Distro, also checks the floorsensor to see if the elevator has arrived at a new floor.

ElevatorDriver: Talks to the elevator hardware through TCP. 

## Borrowed code
The code in driver_elixir was prodived at the start of the project.
The Code in network_utils was provided by Jostein Løwer.
