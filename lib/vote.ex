# Ko Tsz Wang (twk219) and Yujie Wang (yw2919)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Vote do
  # s = server process state (c.f. self/this)

  # -- Handle :VOTE_REPLY ------------------------------------------------------
  # Follower >> Candidate
  # state: State of caller (Follower)
  # msg: term, candidateId, lastLogIndex, lastLogTerm
  def receive_vote_request(state, msgIncome) do
    {cTerm, cId, cLastLogIndex, cLastLogTerm} = msgIncome

    curr_term = state.curr_term
    last_term = Log.last_term(state)
    last_index = Log.last_index(state)

    isCandidateUpToDate =
      case last_term do
        last_term when cLastLogTerm == last_term -> cLastLogIndex >= last_index
        last_term when cLastLogTerm > last_term -> true
        _ -> false
      end

    if curr_term <= cTerm and isCandidateUpToDate do
      state =
        state
        |> State.curr_term(cTerm)
        |> State.role(:FOLLOWER)
        |> State.voted_for(cId)

      msgOutcome = {state.curr_term, true}
      send(cId, {:VOTE_REPLY, msgOutcome})
      state
    else
      msgOutcome = {curr_term, false}
      send(cId, {:VOTE_REPLY, msgOutcome})
      state
    end
  end

  def receive_vote_reply_from_follower(s, mterm, m) do
    Helper.unimplemented([s, mterm, m])
  end

  # -- Handle election timeout -------------------------------------------------
  # 1. Increment current term 
  # 2. Transit to Candidate
  # 3. Vote for self
  # 4. Send vote request
  def receive_election_timeout(state) do
    # 1. Increment current term
    State.inc_term(state)
    # 2. Transit to Candidate
    State.role(state, :CANDIDATE)
    # 3.1. Create a new ballot box
    State.new_voted_by(state)
    # 3.2. Vote for self
    State.add_to_voted_by(state, state.selfP)

    IO.puts("I am candidate now !")

    # 4. Send vote request
    for server <- state.servers do
      %{selfP: candidateId, curr_term: term} = state

      lastLogIndex = Log.last_index(state)
      lastLogTerm = Log.last_term(state)

      msg = {term, candidateId, lastLogIndex, lastLogTerm}

      send(server, {:VOTE_REQUEST, msg})
    end
  end
end
