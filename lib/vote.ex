# Ko Tsz Wang (twk219) and Yujie Wang (yw2919)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Vote do
  # s = server process state (c.f. self/this)

  @type vote_request :: %{
          term: integer,
          candidateId: pid,
          # for debugging
          candidateN: integer,
          lastLogIndex: integer,
          lastLogTerm: integer
        }
  @type vote_reply :: %{
          followerId: pid,
          # for debugging
          followerN: integer,
          term: integer,
          voteGranted: boolean
        }

  @spec send_vote_reply(map, pid, boolean) :: map
  def send_vote_reply(state, candidateId, voteGranted) do
    send(
      candidateId,
      {:VOTE_REPLY,
       %{
         followerId: state.selfP,
         followerN: state.server_num,
         term: state.curr_term,
         voteGranted: voteGranted
       }}
    )

    state
  end

  # -- Handle :VOTE_REQUEST ----------------------------------------------------
  @spec handle_vote_request(map, vote_request()) :: map

  def handle_vote_request(state, msgIncome) do
    %{
      term: cTerm,
      candidateId: cId,
      candidateN: cN,
      lastLogIndex: cLastLogIndex,
      lastLogTerm: cLastLogTerm
    } = msgIncome

    state |> Debug.log("receive vote_request from #{inspect(cN)}")

    last_term = state |> Log.last_term()
    last_index = state |> Log.last_index()

    # TODO: confirmation needed
    isCandidateUpToDate =
      cLastLogTerm >= last_term and cLastLogIndex >= last_index

    # reject the vote request if C.term is less than F.term
    if cTerm < state.curr_term do
      state |> send_vote_reply(cId, false)
    else
      # TODO: Handle vote request if have not reached election_time_minimum yet 

      # If C.term is greater than F.term
      # 1. update F.term 
      # 2. transit to Follower 
      state =
        if cTerm > state.curr_term do
          state
          |> Server.become_follower(cTerm, cId, cN)
        else
          state
        end

      # reject the vote request if candidate is not as least up-to-date as the follower 
      if isCandidateUpToDate and state.voted_for == nil do
        state
        |> State.voted_for(cId)
        |> send_vote_reply(cId, true)
      else
        state |> send_vote_reply(cId, false)
      end
    end
  end

  # -- Handle :VOTE_REPLY ----------------------------------------------------
  @spec handle_vote_reply(map, vote_reply()) :: map

  def handle_vote_reply(state, msgIncome) do
    %{
      followerId: followerId,
      followerN: followerN,
      voteGranted: voteGranted,
      term: term
    } = msgIncome

    if term > state.curr_term do
      state |> Server.become_follower(term, followerId, followerN)
    else
      if voteGranted and state.role != :LEADER do
        state =
          state
          |> Debug.assert(
            term == state.curr_term,
            "#{term} #{state.curr_term}, " <>
              "follower.curr_term should be the same as candidate.curr_term"
          )
          # vote is received from a follower 
          |> State.add_to_voted_by(followerId)
          |> Debug.logs(fn s ->
            IO.ANSI.green() <>
              "Got vote from #{followerN}, " <>
              "#{State.vote_tally(s)} out of #{state.majority} to win" <>
              IO.ANSI.reset()
          end)

        # Got vote from majority, become leader
        if(state |> State.vote_tally() >= state.majority) do
          state
          # Transit to Leader
          |> Server.become_leader()
          # send heartbest to all peers 
          |> AppendEntries.send_heartbeat_all()
        else
          state
        end
      else
        state
      end
    end
  end

  # -- Handle election timeout -------------------------------------------------
  # 1. Increment current term 
  # 2. Transit to Candidate
  # 3. Vote for self
  # 4. Send vote request
  def handle_election_timeout(state) do
    state = state |> Server.become_candidate()

    # 4. Send vote request
    %{selfP: candidateId, server_num: candidateN, curr_term: term} = state
    lastLogIndex = Log.last_index(state)
    lastLogTerm = Log.last_term(state)

    msg = %{
      term: term,
      candidateId: candidateId,
      candidateN: candidateN,
      lastLogIndex: lastLogIndex,
      lastLogTerm: lastLogTerm
    }

    for server <- state.servers, server != self() do
      send(server, {:VOTE_REQUEST, msg})
    end

    state
  end
end
