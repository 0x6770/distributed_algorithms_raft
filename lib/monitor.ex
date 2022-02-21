# distributed algorithms, n.dulay, 10 jan 2022
# coursework, raft consensus, v2

defmodule Monitor do
  # m = monitor process state (c.f. self/this)

  # ---------- Monitor.notify() ------------------------------------------------
  def send_msg(s, msg) do
    send(s.config.monitorP, msg)
    s
  end

  # ---------- Monitor.halt() --------------------------------------------------
  def halt(string) do
    Helper.node_halt("monitor: #{string}")
  end

  # ---------- Monitor setters() -----------------------------------------------
  def clock(m, v), do: Map.put(m, :clock, v)
  def requests(m, i, v), do: Map.put(m, :requests, Map.put(m.requests, i, v))
  def updates(m, i, v), do: Map.put(m, :updates, Map.put(m.updates, i, v))
  def moves(m, v), do: Map.put(m, :moves, v)

  # ---------- Monitor.start() -------------------------------------------------
  def start(config) do
    m = %{
      config: config,
      clock: 0,
      requests: Map.new(),
      updates: Map.new(),
      moves: Map.new()
    }

    Process.send_after(self(), {:PRINT}, m.config.monitor_interval)
    Monitor.next(m)
  end

  # ---------- Monitor next() --------------------------------------------------
  def next(m) do
    receive do
      {:DB_MOVE, db, seqnum, command} ->
        {:MOVE, amount, from, to} = command.cmd

        done = Map.get(m.updates, db, 0)

        if seqnum != done + 1,
          do:
            Monitor.halt(
              "  ** error db #{db}: seq #{seqnum} expecting #{done + 1}"
            )

        moves =
          case Map.get(m.moves, seqnum) do
            nil ->
              # IO.puts "db #{db} seq #{seqnum} = #{done+1}"
              Map.put(m.moves, seqnum, %{amount: amount, from: from, to: to})

            # already logged - check command
            t ->
              if amount != t.amount or from != t.from or to != t.to,
                do:
                  Monitor.halt(
                    " ** error db #{db}.#{done} [#{amount},#{from},#{to}] " <>
                      "= log #{done}/#{map_size(m.moves)} [#{t.amount},#{t.from},#{t.to}]"
                  )

              m.moves
          end

        m
        |> Monitor.moves(moves)
        |> Monitor.updates(db, seqnum)
        |> Monitor.next()

      # client requests seen by leaders
      {:CLIENT_REQUEST, server_num} ->
        value = Map.get(m.requests, server_num, 0)

        m
        |> Monitor.requests(server_num, value + 1)
        |> Monitor.next()

      {:PRINT, term, msg} ->
        IO.puts("  Monitor term = #{term} #{msg}")
        m |> Monitor.next()

      {:PRINT} ->
        clock = m.clock + m.config.monitor_interval

        m = m |> Monitor.clock(clock)

        sorted = m.requests |> Map.to_list() |> List.keysort(0)
        IO.puts("  time = #{clock} client requests seen = #{inspect(sorted)}")
        sorted = m.updates |> Map.to_list() |> List.keysort(0)
        IO.puts("  time = #{clock}      db updates done = #{inspect(sorted)}")

        IO.puts("")
        Process.send_after(self(), {:PRINT}, m.config.monitor_interval)
        m |> Monitor.next()

      # ** ADD ADDITIONAL MESSAGES HERE

      unexpected ->
        Monitor.halt("monitor: unexpected message #{inspect(unexpected)}")
    end
  end
end
