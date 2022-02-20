# Ko Tsz Wang (twk219) and Yujie Wang (yw2919)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Vote do
  # s = server process state (c.f. self/this)

  @type vote_request :: %{
          term: integer,
          candidateP: pid,
          lastLogIndex: integer,
          lastLogTerm: integer
        }
  @type vote_reply :: %{followerP: pid, term: integer, voteGranted: boolean}

  @spec send_vote_reply(pid, integer, boolean) :: nil
  def send_vote_reply(candidateP, term, voteGranted) do
    send(
      candidateP,
      {:VOTE_REPLY,
       %{
         followerP: self(),
         term: term,
         voteGranted: voteGranted
       }}
    )
  end

  # -- Handle :VOTE_REQUEST ----------------------------------------------------
  @spec handle_vote_request(State.state(), vote_request()) :: State.state()

  def handle_vote_request(state, msgIncome) do
    %{
      term: cTerm,
      candidateP: cId,
      lastLogIndex: cLastLogIndex,
      lastLogTerm: cLastLogTerm
    } = msgIncome

    Debug.log("receive vote_request from #{inspect(cId)}")

    last_term = state |> Log.last_term()
    last_index = state |> Log.last_index()

    # TODO: confirmation needed
    isCandidateUpToDate =
      cLastLogTerm >= last_term and cLastLogIndex >= last_index

    # reject the vote request if C.term is less than F.term
    if cTerm < state.curr_term do
      send_vote_reply(cId, state.curr_term, false)
      state
    else
      # TODO: Handle vote request if have not reached election_time_minimum yet 

      # If C.term is greater than F.term
      # 1. update F.term 
      # 2. transit to Follower 
      state =
        if cTerm > state.curr_term do
          state
          |> State.curr_term(cTerm)
          |> State.role(:FOLLOWER)
          |> Timer.restart_election_timer()
        else
          state
        end

      # reject the vote request if candidate is not as least up-to-date as the follower 
      if not isCandidateUpToDate do
        send_vote_reply(cId, state.curr_term, false)
        state
      else
        case state.voted_for do
          nil ->
            state =
              state
              |> State.voted_for(cId)
              |> State.role(:FOLLOWER)

            send_vote_reply(cId, state.curr_term, true)
            state

          candidate when candidate == cId ->
            send_vote_reply(cId, state.curr_term, true)
            state

          _ ->
            send_vote_reply(cId, state.curr_term, false)
            state
        end
      end
    end
  end

  # -- Handle :VOTE_REPLY ----------------------------------------------------
  @spec handle_vote_reply(State.state(), vote_reply()) :: State.state()

  def handle_vote_reply(state, msgIncome) do
    %{followerP: followerId, voteGranted: voteGranted, term: term} = msgIncome

    if term > state.curr_term do
      state
      |> State.curr_term(term)
      |> State.role(:FOLLOWER)
      |> Timer.restart_election_timer()
    end

    if voteGranted do
      state =
        state
        |> Debug.assert(
          term == state.curr_term,
          "follower.curr_term should be the same as candidate.curr_term"
        )
        # vote is received from a follower 
        |> State.add_to_voted_by(followerId)

      IO.puts(
        IO.ANSI.green() <>
          "Got #{State.vote_tally(state)} vote." <>
          "Majority is #{state.majority}" <> IO.ANSI.reset()
      )

      # Got vote from majority, become leader
      if(state |> State.vote_tally() >= state.majority) do
        Debug.log("I'm leader now !")

        # Transit to Leader
        state = state |> State.role(:LEADER) |> Timer.cancel_election_timer()

        # Send AppendEntries request to all servers
        for server <- state.servers do
          state |> Timer.restart_append_entries_timer(server)
          send(server, {:APPEND_ENTRIES_REQUEST})
        end

        state
      else
        state
      end
    else
      state
    end
  end

  # -- Handle election timeout -------------------------------------------------
  # 1. Increment current term 
  # 2. Transit to Candidate
  # 3. Vote for self
  # 4. Send vote request
  def handle_election_timeout(state) do
    state =
      state
      # 1. Increment current term
      |> State.inc_term()
      # 2. Transit to Candidate
      |> State.role(:CANDIDATE)
      # 3.1. Create a new ballot box
      |> State.new_voted_by()
      # 3.2. Vote for self
      |> State.add_to_voted_by(state.selfP)
      |> Timer.restart_election_timer()

    Debug.log("I am candidate now !")
    # IO.puts("#{System.os_time()} => I am candidate now !")

    # 4. Send vote request
    %{selfP: candidateP, curr_term: term} = state
    lastLogIndex = Log.last_index(state)
    lastLogTerm = Log.last_term(state)

    msg = %{
      term: term,
      candidateP: candidateP,
      lastLogIndex: lastLogIndex,
      lastLogTerm: lastLogTerm
    }

    for server <- state.servers do
      send(server, {:VOTE_REQUEST, msg})
    end

    state
  end
end
