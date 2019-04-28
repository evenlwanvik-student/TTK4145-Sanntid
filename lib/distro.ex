defmodule Distro do
  @moduledoc """
  This modules handels the information that shall be passed between the different nodes. The GenServer keeps
  a map of all the orders for all the elevators. The map is sorted by keys, the keys are the names of the 
  different nodes that the node can reach. 
  Communications is handled by calls and cast to the Distro modules on the other elevators. 
  """
  @behaviour Plug

  use GenServer
  @server_name :process_distro

  @doc """
  Start the GenServer with an empty map with one key, this node.
  """
  def start_link([]) do
    GenServer.start_link(__MODULE__, %{Node.self() => []}, [{:name, @server_name}])
  end

  @doc """
  Inits the GenServer by spawning the two functions that checks for new nodes and removes nodes that 
  are gone.
  """
  @impl true
  def init(orders) do
    Process.spawn(fn -> check_for_new_nodes() end, [])
    Process.spawn(fn -> poll_for_dead_nodes() end, [])
    {:ok, orders}
  end

  # ------------- API

  @doc """
  Adds an order to a node and sets the light for this order. 

  """
  def add_order({pid, node}, order, node_for_order) do
    GenServer.cast({pid, node}, {:add_order, order, node_for_order})
  end

  @doc """
  Removes an order from a node and turns of the light for this order. 
  """
  def remove_order({pid, node}, order, node_for_order) do
    GenServer.cast({pid, node}, {:remove_order, order, node_for_order})
  end

  @doc """
  Ruturns all the orders for this node.
  """
  def get_all_orders(pid, node) do
    GenServer.call({pid, node}, {:get_all_orders})
  end

  @doc """
  Distributs a new order. Finds the best node through the get score functions, then adds the node to this 
  node and tells the other nodes which elevator is handeling the order.
  """     
  def new_order(pid, order) do
    GenServer.cast(pid, {:new_order, order})
  end

  @doc """
  Adds a new node and all its orders to this genserver.
  """
  def add_node(pid, node) do
    GenServer.cast(pid, {:add_node, node})
  end

  @doc """
  Removes the given nodes from this genserver.
  """  
  def remove_nodes(pid, nodes) do
    GenServer.cast(pid, {:remove_nodes, nodes})
  end

  @doc """
  Returns the map stored in this Genserver.
  """
  def get_map(pid) do
    GenServer.call(pid, {:get_map})
  end

  @doc """
  Returns true. This function is used to check if a node is responsive.
  """
  def is_alive?(pid, node) do
    GenServer.call({pid, node}, {:is_alive?})
  end

  @doc """
  Checks if there is any handleable orders at a floor. Returns true or false. 
  """
  def check_for_orders_at_floor(pid, floor, direction) do
    GenServer.call(pid, {:check_for_orders_at_floor, floor, direction})
  end

  @doc """
  Gets the optimal traveldirection according to the current orders on the elevator. 
  """
  def get_direction(pid, elevator_state) do
    GenServer.call(pid, {:get_direction, elevator_state})
  end

  # ------------- Casts and calls

  @impl true
  def handle_cast({:add_order, order, node_for_order}, orders) do
    if order.direction != :cab || node_for_order == Node.self() do
      ElevatorDriver.set_order_button_light(:process_driver, order.direction, order.floor, :on)
    end

    {:noreply,
     Map.put(orders, node_for_order, Enum.uniq([order | Map.fetch!(orders, node_for_order)]))}
  end

  @impl true
  def handle_cast({:remove_order, order, node_for_order}, orders) do
    if Node.self() == node_for_order && Enum.any?(orders[Node.self()], fn x -> x == order end) do
      Node.list()
      |> Enum.each(fn x -> Distro.remove_order({:process_distro, x}, order, node_for_order) end)
    end

    if order.direction != :cab || node_for_order == Node.self() do
      ElevatorDriver.set_order_button_light(:process_driver, order.direction, order.floor, :off)
    end

    {:noreply,
     Map.put(
       orders,
       node_for_order,
       Map.fetch!(orders, node_for_order) |> Enum.reject(fn x -> x == order end)
     )}
  end

  def handle_cast({:new_order, order}, orders) do
    #get_score returns a %NodeScore struct. Extracts the node with x.node
    node_for_order =
        (orders
        |> Map.keys()
        |> Enum.map(fn x -> get_score(Map.fetch!(orders, x), x, order) end)
        |> Enum.min_by(fn x -> x.score end)
        ).node

    Node.list() |> Enum.each(fn x -> 
        Distro.add_order({:process_distro, x}, order, node_for_order) 
    end)

    ElevatorDriver.set_order_button_light(:process_driver, order.direction, order.floor, :on)
    {:noreply,
    Map.put(orders, node_for_order, Enum.uniq([order | Map.fetch!(orders, node_for_order)]))}
  end

  def handle_cast({:remove_nodes, nodes}, orders) do
    {:noreply, orders |> Map.drop(nodes)}
  end

  @impl true
  def handle_call({:get_all_orders}, _from, orders) do
    {:reply, Map.fetch!(orders, Node.self()), orders}
  end

  def handle_call({:get_map}, _from, orders) do
    {:reply, orders, orders}
  end

  def handle_call({:is_alive?}, _from, orders) do
    {:reply, true, orders}
  end

  @impl true
  def handle_cast({:add_node, node}, orders) do
    {:noreply, Map.put(orders, node, Distro.get_all_orders(:process_distro, node))}
  end

  def handle_call({:check_for_orders_at_floor, direction, current_floor}, _from, orders) do
    cond do
      current_floor == 0 ->
        {:reply, true, orders}

      current_floor == 3 ->
        {:reply, true, orders}

      Map.fetch!(orders, Node.self())
      |> Enum.any?(fn x -> stop_for_order?(x, direction, current_floor) end) ->
        {:reply, true, orders}

      !orders_beyond(direction, current_floor, Map.fetch!(orders, Node.self())) ->
        {:reply, true, orders}

      true ->
        {:reply, false, orders}
    end
  end

  def handle_call({:get_direction, elevator_state}, _from, orders) do
    own_orders = Map.fetch!(orders, Node.self())
    above = own_orders |> Enum.count(fn x -> x.floor > elevator_state.floor end)
    below = own_orders |> Enum.count(fn x -> x.floor < elevator_state.floor end)

    cond do
      Enum.empty?(Enum.filter(own_orders, fn x -> x.floor != elevator_state.floor end)) ->
        {:reply, :none, orders}

      own_orders |> Enum.any?(fn x -> order_in_traveling_direction?(x, elevator_state) end) ->
        {:reply, elevator_state.direction, orders}

      above >= below ->
        {:reply, :up, orders}

      below > above ->
        {:reply, :down, orders}
    end
  end

# ------------- Help functions


  @doc """
  Checks if a given order is in the traveldirection of the elevator.
  """
  defp order_in_traveling_direction?(order, elev_state) do
    cond do
      elev_state.direction == :up ->
        order.floor > elev_state.floor

      elev_state.direction == :down ->
        order.floor < elev_state.floor

      true ->
        false
    end
  end

  @doc """
  Checks if there are any orders beyond a given floor in the traveling direction of the elevator. 
  """
  defp orders_beyond(direction, floor, orders) do
    case direction do
      :up -> orders |> Enum.filter(fn x -> x.floor > floor end) |> Enum.any?()
      :down -> orders |> Enum.filter(fn x -> x.floor < floor end) |> Enum.any?()
      :idle -> false
      :motor_dead -> false
    end
  end

  @doc """
  Checks if the elevator should stop for a given order. 
  """
  defp stop_for_order?(order, direction, current_floor) do
    cond do
      {order.direction, order.floor} == {:cab, current_floor} -> true
      {order.direction, order.floor} == {direction, current_floor} -> true
      true -> false
    end
  end

  @doc """
  Distributes all orders on a node to the other nodes. This is done if the elevator stops working.
  """
  def flush_orders do
    IO.puts("Flushing orders:")

    Distro.get_all_orders(:process_distro, Node.self())
    |> Enum.each(fn x -> Distro.new_order(:process_distro, x) end)
  end

  @doc """
  Checks if any new nodes has joined the network every 500ms. If a new node is found this node is 
  added to the GenServer through the add_node function. This function spawns a new version of itself before
  running.
  """
  defp check_for_new_nodes do
    Process.sleep(500)
    Process.spawn(fn -> check_for_new_nodes() end, [])

    NetworkUtils.all_nodes()
    |> Enum.each(fn x ->
      case Distro.get_map(:process_distro) |> Map.has_key?(x) do
        false ->
          # This makes the process crash if the genserver is not alive on other node, this is intended. 
          if Distro.is_alive?(:process_distro, x) do
            Distro.add_node(:process_distro, x)
          end

        true ->
          :nothing
      end
    end)
  end

  @doc """
  Checks if any of the nodes that were on the network has died. If any nodes are found their orders are 
  redistributed to the other nodes on the network. This function spawn a new instance of itself.
  """
  defp poll_for_dead_nodes do
    Process.sleep(20)
    Process.spawn(fn -> poll_for_dead_nodes end, [])

    lost_nodes =
      Distro.get_map(:process_distro)
      |> Map.keys()
      |> Enum.filter(fn x -> not (NetworkUtils.all_nodes() |> Enum.any?(fn y -> x == y end)) end)

    case Enum.empty?(lost_nodes) do
      false ->
        IO.puts("Removing dead nodes:")
        IO.puts(Kernel.inspect(lost_nodes))

        lost_nodes
        |> Enum.each(fn x ->
          Distro.get_map(:process_distro)
          |> Map.fetch!(x)
          |> Enum.each(fn y ->
            if not (y.direction == :cab) do
              Distro.new_order(:process_distro, y)
            end
          end)
        end)

        Distro.remove_nodes(:process_distro, lost_nodes)

      true ->
        :nothing
    end
  end

  @doc """
  Returns a NodeScore struct for a given node and order. The node with the lowest score is most fitting.
  """
  defp get_score(orders_on_node, node, order) do
    cond do
        not (node in NetworkUtils.all_nodes) ->
            %NodeScore{node: node, score: 1000}

        order.direction == :cab && node == Node.self() ->
            %NodeScore{node: node, score: 0}

        order.direction == :cab && node != Node.self() ->
            %NodeScore{node: node, score: 100}

        ElevatorState.get_state(:process_elevator, node).direction == :motor_dead ->
            %NodeScore{node: node, score: 100}

        order_in_traveling_direction?(order, ElevatorState.get_state(:process_elevator, node)) ->
            %NodeScore{
                node: node,
                score: 1 + abs(order.floor - ElevatorState.get_state(:process_elevator, node).floor)
            }

        true ->
            score_node =
            orders_on_node |> Enum.map(fn x -> Kernel.abs(x.floor - order.floor) end) |> Enum.sum()
            %NodeScore{
                node: node,
                score:
                score_node +
                Kernel.abs(ElevatorState.get_state(:process_elevator, node).floor - order.floor)
            }
    end
  end
end
