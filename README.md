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

## Module introductions

There are eight modules in total, one for initialization, five supervised children, and two helper libraries; 
* main.ex has initialization procedures; it can either start multiple elevator simulations or one connected to elevator hardware. It starts and supervises the necessary child processes (supervised processes are mentioned below) for the elevator to start running.
* driver_elixir.ex is the elevator hardware driver. The module 'ElevatorDriver' is one of the supervised processes
* poller.ex is for polling I/O, The module 'Poller' is one of the supervised processes
* network.ex handles node connection and communication. The module 'Network' is one of the supervised processes
* distro.ex handles message passing between elevators. The module 'Distro' is one of the supervised processes.
* state_machine.ex handles the state of the elevator. The module 'ElevatorState' is one of the supervised processes.
* utils.ex is a library that defines structures being used in our state machine. 
* network_utils.ex has user friendly network API for elixir. 

## Borrowed code
The code in driver_elixir was prodived at the start of the project.
The Code in network_utils was provided by Jostein Løwer.
