defmodule Network do
  @moduledoc """
  Module for handling node connection and communication. 
  """

  use GenServer

  @server_pid :process_network
  @broadcastport 27000
  @listenport 27001
  @cookie :unicorn
  # Your address and 255 at the end or just 255.255.255.255
  @broadcastIP {255, 255, 255, 255}
  @msgtimeout 1000

  @doc """
  Start_link is called from supervisor
  """
  def start_link(name \\ "elevator", broadcastport \\ @broadcastport, listenport \\ @listenport) do
    IO.puts(name)
    GenServer.start_link(__MODULE__, [name, broadcastport, listenport], [{:name, @server_pid}])
  end

  @doc """
  Initialize a broadcast and listen function for connecting nodes
  """
  def init([name, broadcastport, listenport]) do
    IO.puts(Kernel.inspect(name))
    nodename = NetworkUtils.boot_node(name)
    IO.puts("Initializing #{nodename}")
    Node.set_cookie(Node.self(), @cookie)

    # --- broadcast myself ---
    case :gen_udp.open(broadcastport, [:list, {:active, false}, {:broadcast, true}]) do
      {:ok, broadcastsocket} ->
        IO.puts("broadcast socket open")
        Process.spawn(__MODULE__, :broadcast, [broadcastsocket, nodename, listenport], [])

      {:error, reason} ->
        IO.puts("Failure to open broadcast port. Reason: #{reason}")
    end

    # --- listen for other nodes ---
    case :gen_udp.open(listenport, [:list, {:active, false}]) do
      {:ok, listensocket} ->
        IO.puts("listen socket open")
        Process.spawn(__MODULE__, :listen, [listensocket], [])

      {:error, reason} ->
        IO.puts("Failure to open listen port. Reason: #{reason}")
    end

    {:ok, true}
  end

  # ------------ ping/pong configuration

  @doc """
  Broadcast my own address on listenport
  """
  def broadcast(socket, myname, listenport) do
    :gen_udp.send(socket, @broadcastIP, listenport, myname)
    :timer.sleep(@msgtimeout * 2)
    broadcast(socket, myname, listenport)
  end

  @doc """
  Listens for any new node that wants to join the network.
  Doesn't try to connect (ping) if itself or in the node list.
  """
  def listen(socket) do
    case :gen_udp.recv(socket, @listenport, @msgtimeout) do
      {:ok, {ip, port, recv_node}} ->
        if recv_node not in ([Node.self() | Node.list()]
                             |> List.flatten()
                             |> Enum.map(&to_charlist(&1))) do
          Process.send(:process_network, {:connect_node, recv_node}, [])
          listen(socket)
        end

      {:error, :timeout} ->
        listen(socket)
    end

    listen(socket)
  end

  # ------------ casts and calls

  @doc """
  Called when succesfully connected to new node
  """
  def handle_info({:connect_node, othernode}, state) do
    IO.puts("Connecting to new node")
    Node.ping(othernode |> to_string |> String.to_atom())
    {:noreply, state}
  end
end
