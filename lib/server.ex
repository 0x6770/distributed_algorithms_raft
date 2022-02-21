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
        {:APPEND_ENTRIES_TIMEOUT, _mterm, followerP} = dmsg ->
          s
          |> Debug.message("-atim", dmsg)
          |> AppendEntries.handle_append_entries_timeout(followerP)

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

        {:DB_REPLY, msg} ->
          send(
            msg.clientP,
            {:CLIENT_REPLY, {msg.cid, :OK, s.leaderP, s.leaderN}}
          )

          s

        unexpected ->
          Helper.node_halt(
            "************* Server: unexpected message #{inspect(unexpected)}"
          )
      end

    Server.next(s)
  end

  def become_follower(s, mterm, leaderP, leaderN) do
    s
    |> Timer.restart_election_timer()
    |> State.role(:FOLLOWER)
    |> State.leaderP(leaderP)
    |> State.leaderN(leaderN)
    |> Debug.log("I am follower now !")
    |> State.curr_term(mterm)
    |> State.voted_for(nil)
  end

  def become_candidate(s) do
    s
    |> Timer.restart_election_timer()
    |> State.role(:CANDIDATE)
    |> Debug.log("I am candidate now !")
    |> State.inc_term()
    |> State.voted_for(s.selfP)
    |> State.new_voted_by()
    |> State.add_to_voted_by(s.selfP)
    |> Debug.logs(fn s ->
      "#{s.server_num} vote for self, " <>
        "#{State.vote_tally(s)} out of #{s.majority} to win"
    end)
  end

  def become_leader(s) do
    s
    |> Timer.cancel_election_timer()
    |> State.role(:LEADER)
    |> State.leaderP(self())
    |> State.leaderN(s.server_num)
    |> Debug.log(
      IO.ANSI.green_background() <>
        IO.ANSI.black() <> "I am leader now !" <> IO.ANSI.reset()
    )
    |> State.init_next_index()
    |> State.init_match_index()
  end

  def execute_committed_entries(s) do
    case s.last_applied < s.commit_index do
      true ->
        new_entries_range = (s.last_applied + 1)..s.commit_index
        client_requests = Log.get_entries(s, new_entries_range)

        for {_index, entry} <- client_requests do
          send(s.databaseP, {:DB_REQUEST, entry.client_request})
        end

        s |> State.last_applied(s.commit_index)

      false ->
        s
    end
  end
end
