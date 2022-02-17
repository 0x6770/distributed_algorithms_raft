# Ko Tsz Wang (twk219) and Yujie Wang (yw2919)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Server do
  # s = server process state (c.f. self/this)

  # ---------- Server.start() ----------------------------------------------------
  def start(config, server_num) do
    config =
      config
      |> Configuration.node_info("Server", server_num)
      |> Debug.node_starting()

    receive do
      {:BIND, servers, databaseP} ->
        State.initialise(config, server_num, servers, databaseP)
        |> Timer.restart_election_timer()
        |> Server.next()
    end

    # receive
  end

  # start

  # ---------- Server.next() -----------------------------------------------------
  def next(s) do
    s =
      receive do
        {:APPEND_ENTRIES_REQUEST, msg} ->
          Helper.unimplemented(msg)

        {:APPEND_ENTRIES_REPLY, msg} ->
          Helper.unimplemented(msg)

        {:VOTE_REQUEST, msg} ->
          Helper.unimplemented(msg)

        {:VOTE_REPLY, msg} ->
          Helper.unimplemented(msg)

        {:ELECTION_TIMEOUT, msg} ->
          Helper.unimplemented(msg)

        {:APPEND_ENTRIES_TIMEOUT, msg} ->
          Helper.unimplemented(msg)

        {:CLIENT_REQUEST, msg} ->
          Helper.unimplemented(msg)

        unexpected ->
          nil
          # omitted
      end

    # receive

    Server.next(s)
  end

  # next
end

# Server
