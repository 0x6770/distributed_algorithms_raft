# Ko Tsz Wang (twk219) and Yujie Wang (yw2919)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule ClientReq do
  # s = server process state (c.f. self/this)

  def receive_request_from_client(s, command) do
    case s.role do
      :LEADER ->
        #commit to leader's log
        s =
          s
          |> State.commit_index(s.commit_index + 1)
          |> Log.append_entry(%{term: s.curr_term, command: command})

        #Create message for send
        m = Message.initialise(s,command)
        #send append entries request to all servers
        for server <- s.servers do
          send(server,{:APPEND_ENTRIES_REQUEST, m})
        end
        #return state of leader
        s

      :FOLLOWER ->
        s
      :CANDIDATE ->
        s
      unexpected ->
        Helper.node_halt(
        "************* Client_req: unexpected role of #{inspect(unexpected)}"
        )
    end
  end
end
