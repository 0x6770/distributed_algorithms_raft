# Ko Tsz Wang (twk219) and Yujie Wang (yw2919)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

# various helper functions

defmodule Helper do
  def node_lookup(name) do
    addresses = :inet_res.lookup(name, :in, :a)
    # get octets for 1st ipv4 address
    {a, b, c, d} = hd(addresses)
    :"#{a}.#{b}.#{c}.#{d}"
  end

  def node_ip_addr do
    # get interfaces
    {:ok, interfaces} = :inet.getif()
    # get data for 1st interface
    {address, _gateway, _mask} = hd(interfaces)
    # get octets for address
    {a, b, c, d} = address
    "#{a}.#{b}.#{c}.#{d}"
  end

  def node_string() do
    "#{node()} (#{node_ip_addr()})"
  end

  # nicely stop and exit the node
  def node_exit do
    # System.halt(1) for a hard non-tidy node exit
    System.stop(0)
  end

  def node_halt(message) do
    IO.puts("  Node #{node()} exiting - #{message}")
    node_exit()
  end

  def node_exit_after(duration) do
    Process.sleep(duration)
    IO.puts("  Node #{node()} exiting - maxtime reached")
    node_exit()
  end

  def node_nap(timeout, message) do
    IO.puts("Node #{node()} Going to Sleep for #{timeout} ms - #{message}")
    Process.sleep(timeout)
  end

  def node_sleep(message) do
    IO.puts("Node #{node()} Going to Sleep - #{message}")
    Process.sleep(:infinity)
  end

  def unimplemented(args) do
    for arg <- binding() do
      _ = arg
    end

    raise "Not Implemented"
  end

  def to_histogram(list) do
    histogram = Map.new()

    Enum.reduce(list, histogram, fn element, acc ->
      Map.update(acc, element, 1, fn count -> count + 1 end)
    end)
  end
end
