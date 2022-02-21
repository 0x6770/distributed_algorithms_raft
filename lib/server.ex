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
  end

  # ---------- Server.next() -----------------------------------------------------
  def next(s) do
    s = s |> Server.execute_committed_entries()

    # used to discard old messages
    curr_term = s.curr_term
    # used to discard old election timeouts
    curr_election = s.curr_election

    s =
      receive do
        # ---------- Stale Message ---------------------------------------------

        # Reject, send Success=false and newer term in reply
        {:APPEND_ENTRIES_REQUEST, mterm, m} when mterm < curr_term ->
          s
          |> Debug.message("-areq", "stale #{mterm} #{inspect(m)}")
          |> AppendEntries.send_entries_reply_to_leader(m.leaderP)

        # Discard any other stale messages
        {_mtype, mterm, _m} = msg when mterm < curr_term ->
          s |> Debug.received("stale #{inspect(msg)}")

        # ---------- AppendEntries ---------------------------------------------
        # Leader >> All
        {:APPEND_ENTRIES_REQUEST, _mterm, m} = msg ->
          s
          |> Debug.message("-areq", msg)
          |> AppendEntries.receive_append_entries_request_from_leader(m)

        # Follower >> Leader
        {:APPEND_ENTRIES_REPLY, _mterm, m} = msg ->
          s
          |> Debug.message("-arep", msg)
          |> AppendEntries.receive_append_entries_reply_from_follower(m)

        # Leader >> Leader
        {:APPEND_ENTRIES_TIMEOUT, _mterm, followerP} = msg ->
          s
          |> Debug.message("-atim", msg)
          |> AppendEntries.receive_append_entries_timeout(followerP)

        # ---------- Vote ------------------------------------------------------

        # Candidate >> All
        {:VOTE_REQUEST, msg} = dmsg ->
          s
          |> Debug.message("-vreq", dmsg)
          |> Vote.handle_vote_request(msg)

        # Follower >> Candidate
        {:VOTE_REPLY, msg} = dmsg ->
          s
          |> Debug.message("-vrep", dmsg)
          |> Vote.handle_vote_reply(msg)

        # Self {Follower, Candidate} >> Self
        {:ELECTION_TIMEOUT, _} = msg ->
          s
          |> Debug.received("-etim", msg)
          |> Vote.handle_election_timeout()

        # ---------- ClientReq -------------------------------------------------

        # Client >> Leader
        {:CLIENT_REQUEST, msg} = dmsg ->
          s
          |> Debug.message("-creq", dmsg)
          |> ClientReq.handle_client_request(msg)

        unexpected ->
          Helper.node_halt(
            "************* Server: unexpected message #{inspect(unexpected)}"
          )
      end

    Server.next(s)
  end

  def follower_if_higher(s, mterm) do
    Helper.unimplemented([s, mterm])
  end

  def become_follower(s, mterm) do
    s
    |> State.role(:FOLLOWER)
    |> State.curr_term(mterm)
  end

  def become_candidate(s) do
    Helper.unimplemented(s)
  end

  def become_leader(s) do
    s
    |> State.role(:LEADER)
    |> State.inc_term()
    |> State.init_next_index()
    |> State.init_match_index()
  end

  def execute_committed_entries(s) do
    s =
      s
      |> State.set_commit_index
    case s.last_applied < s.commit_index do
      true ->
        new_entries_range = (s.last_applied+1)..s.commit_index
        client_requests = Log.get_entries(s,new_entries_range)
        for {_index,entry} <- client_requests do
          send(s.databaseP,{:DB_REQUEST, entry.command})
        end
        s
        |> State.last_applied(s.commit_index)
      false ->
        s
    end

  end
end
