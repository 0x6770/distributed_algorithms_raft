# Ko Tsz Wang (twk219) and Yujie Wang (yw2919)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule ClientReq do
  # s = server process state (c.f. self/this)
  @type cid :: {integer, integer}
  @type cmd :: {:MOVE, integer, integer, integer}
  @type client_request :: %{clientP: pid, cid: cid, cmd: cmd}

  @spec handle_client_request(map, client_request) :: map
  def handle_client_request(s, client_request, level \\ 3) do
    %{clientP: clientP, cid: cid, cmd: cmd} = client_request

    if Debug.option?(s.config, "R", level) do
      IO.puts(
        "#{System.os_time(:millisecond)} => CLIENT request : #{inspect(client_request)}"
      )
    end

    case s.role do
      :LEADER ->
        # add to leader's log
        s =
          s
          |> Log.append_entry(%{
            term: s.curr_term,
            client_request: client_request
          })
          |> Monitor.send_msg({:CLIENT_REQUEST, s.server_num})

        # Create message for send
        m = Message.initialise(s, client_request)
        # send append entries request to all servers
        for server <- s.servers do
          if server != self() do
            send(server, {:APPEND_ENTRIES_REQUEST, Message.term(m), m})
          end
        end

        # return state of leader
        s

      _ ->
        send(
          clientP,
          {:CLIENT_REPLY, {cid, :NOT_LEADER, s.leaderP, s.leaderN}}
        )

        s
    end
  end
end
