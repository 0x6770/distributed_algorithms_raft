# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Database do
  # d = database process state (c.f. self/this)

  # ---------- Database setters() ----------------------------------------------
  def seqnum(d, v), do: Map.put(d, :seqnum, v)
  # def balances(d, i, v), do: Map.put(d, :balances, Map.put(d.balances, i, v))

  def balances(d, i, v) do
    content =
      case File.read(d.file_name) do
        {:ok, ""} -> "{}"
        {:ok, content} -> content
        _ -> "{}"
      end

    IO.puts("Content => #{inspect(content)}")

    {:ok, json_balances} = JSON.decode(content)

    balances = Map.put(json_balances, to_string(i), v)

    IO.puts(
      IO.ANSI.cyan() <> "#{inspect(JSON.encode(balances))}" <> IO.ANSI.reset()
    )

    {:ok, json} = JSON.encode(balances)
    File.write(d.file_name, json, [:write])
    d
  end

  def write(d) do
    {:ok, json} = JSON.encode(d.balances)
    File.write(d.file_name, json, [:write])

    IO.puts(
      IO.ANSI.cyan() <> "#{inspect(JSON.encode(d.balances))}" <> IO.ANSI.reset()
    )
  end

  def erase(d) do
    File.rm(d.file_name)
    d
  end

  # ---------- Database.start() ------------------------------------------------
  def start(config, db_num) do
    receive do
      {:BIND, serverP} ->
        # initialise database state variables
        d = %{
          config: config,
          file_name: "./database/db_#{db_num}.json",
          db_num: db_num,
          serverP: serverP,
          seqnum: 0,
          balances: Map.new()
        }

        d
        |> Database.erase()
        |> Database.next()
    end
  end

  # ---------- Database.next() -------------------------------------------------
  def next(d) do
    receive do
      {:DB_REQUEST, client_request} ->
        IO.puts("DB receive: #{inspect(client_request)}")
        {:MOVE, amount, account1, account2} = client_request.cmd

        d = Database.seqnum(d, d.seqnum + 1)

        balance1 = Map.get(d.balances, account1, 0)
        balance2 = Map.get(d.balances, account2, 0)

        d = Database.balances(d, account1, balance1 + amount)
        d = Database.balances(d, account2, balance2 - amount)

        d
        |> Monitor.send_msg({:DB_MOVE, d.db_num, d.seqnum, client_request})
        |> Database.send_reply_to_server(client_request)
        |> Database.next()

      unexpected ->
        Helper.node_halt(
          " *********** Database: unexpected message #{inspect(unexpected)}"
        )
    end
  end

  def send_reply_to_server(d, db_result) do
    send(d.serverP, {:DB_REPLY, db_result})
    d
  end
end
