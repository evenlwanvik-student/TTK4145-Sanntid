# Project

Elevator Project in TTK4145 Real-time Programming written in Elixir.

[Project spesification](https://github.com/TTK4145/Project)

## Description
Main requirements:
* No orders are lost
* Multiple elevators should be more efficient than one
* An individual elevator should behave sensibly and efficiently
* The lights should function as expected

The FAT test was executed on 1 to 3 elevators with four floors each.  The number of elevators or floors are not hardcoded, and there is virtually no limit to the number of elevator or floors (of course there is a limit for performance and memory saving reasons).  We got 43/45 on our FAT test; the two missing points was because we did not store the state and orders on the controller (in this case the computer) in case of power loss. Although the orders were fulfilled on by another elevator, the affected elevator should still complete its previous orders when it is back online.

## Solution

## Module introductions

There are eight modules in total; 
* 'main' is the initialization module; it can either start multiple elevator simulations or one connected to elevator hardware. It starts and supervises the necessary child processes for the elevator to start running.
* "driver_elixir" is the code for the elevator hardware driver
> its module 'ElevatorDriver' is supervised by the main process.
* "poller" continiously polls
> its module 'Poller' is supervised by the main process.
* "poller" continiously polls
> its module 'Poller' is supervised by the main process.



These are the supervisor; 'main' the elevator statemachine, 'ElevatorState' (the networks module), Network, the distributor of orders, Distro, the pollers, Poller, and the driver for the elevator, ElevatorDriver. The helpers are Utils and NetworkUtils. 

Main: Handles the initilization and supervising of the other modules. It restarts them at the previous state if they crash.

ElevatorState: Keeps track of the elevator through the ElevatorDriver module. Keeps state as a floor number and a traveling direction or idle.

Network: Establishes conection to other nodes on the network thorough UDP. This is done by brodcasting its node name. 

Distro: Keeps track of all orders for all elevators on the network. These are kept as state in the GenServer. Gets new orders from the pollers. Also calculates which elevator is best able to handle new orders. 

Poller: Routinly check the buttons on the elevator and updates the Distro, also checks the floorsensor to see if the elevator has arrived at a new floor.

ElevatorDriver: Talks to the elevator hardware through TCP. 

## Borrowed code
The code in driver_elixir was prodived at the start of the project.
The Code in network_utils was provided by Jostein Løwer.
