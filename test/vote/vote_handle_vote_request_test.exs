defmodule VoteTest.HandleVoteRequest do
  use ExUnit.Case

  setup do
    argv = [
      # node_suffix
      "TEST@127.0.0.1",
      # raft_timelimit
      "15000",
      # debug_level
      "100",
      # debug_options
      "+state",
      # n_servers
      "3",
      # n_clients
      "0",
      # setup
      "default",
      # start_function
      "cluster_wait"
    ]

    config = Configuration.node_init(argv)
    config = Configuration.node_info(config, "test")
    {:ok, config}
  end

  def setup_state(
        {
          currentTerm,
          lastLogTerm,
          lastLogIndex
        },
        config
      ) do
    state = State.initialise(config, 0, [], self())
    state = State.curr_term(state, currentTerm)

    if lastLogIndex != 0 do
      state =
        List.foldl(Enum.to_list(1..(lastLogIndex - 1)), state, fn n, acc ->
          Log.append_entry(acc, {})
        end)

      Log.append_entry(state, %{term: lastLogTerm})
    else
      state
    end
  end

  def test_handle_vote_request(candidate, follower, config, expect) do
    {cCurrentTerm, cLastLogTerm, cLastLogIndex} = candidate

    fState = setup_state(follower, config)

    # msg: term, candidateId, lastLogIndex, lastLogTerm
    msg = %{
      term: cCurrentTerm,
      candidateId: self(),
      candidateN: 0,
      lastLogIndex: cLastLogIndex,
      lastLogTerm: cLastLogTerm
    }

    fState = Vote.handle_vote_request(fState, msg)

    assert_received {:VOTE_REPLY, reply}

    %{followerId: _pid, followerN: _, term: term, voteGranted: voteGranted} =
      reply

    assert fState.role == :FOLLOWER
    # check if the follower has voted as expected
    assert voteGranted == expect,
           "actual = #{voteGranted}; expect = #{expect}\n" <>
             "C.curr_term = #{inspect(cCurrentTerm)}\n" <>
             "F.curr_term = #{inspect(fState.curr_term)}\n" <>
             "C.last_term = #{inspect(cLastLogTerm)}\n" <>
             "F.last_term = #{inspect(fState |> Log.last_term())}\n" <>
             "C.last_index = #{inspect(cLastLogIndex)}\n" <>
             "F.last_index = #{inspect(fState |> Log.last_index())}"

    # check if the follower has updated its currentTerm if needed
    assert term == max(cCurrentTerm, fState.curr_term),
           "actual = #{term}; expect = #{max(cCurrentTerm, fState.curr_term)}\n" <>
             "C.curr_term = #{inspect(cCurrentTerm)}\n" <>
             "F.curr_term = #{inspect(fState.curr_term)}"

    # assert_receive({:ELECTION_TIMEOUT, _}, 2000, "vote = #{voteGranted}")
  end

  test "test Log.append_entry", config do
    state = State.initialise(config, 0, [], self())
    assert Log.last_term(state) == 0
    assert Log.last_index(state) == 0
    state = Log.append_entry(state, {})
    assert Log.last_index(state) == 1
    state = Log.append_entry(state, {})
    assert Log.last_index(state) == 2
  end

  test "test setup_state", config do
    curr_term = 12
    last_index = 10
    last_term = 3
    state = setup_state({curr_term, last_term, last_index}, config)
    # IO.puts(inspect(state))
    assert Log.last_index(state) == last_index
  end

  test "test Vote.handle_vote_request() C.term < F.term", config do
    # { currentTerm, lastLogTerm, lastLogIndex }
    candidate = {1, 0, 0}
    follower = {2, 0, 0}
    test_handle_vote_request(candidate, follower, config, false)
  end

  test "test Vote.handle_vote_request() C.term == F.term", config do
    # { currentTerm, lastLogTerm, lastLogIndex }
    candidate = {1, 0, 0}
    follower = {1, 0, 0}
    test_handle_vote_request(candidate, follower, config, true)
  end

  test "test Vote.handle_vote_request() C.term > F.term", config do
    # { currentTerm, lastLogTerm, lastLogIndex }
    candidate = {2, 0, 0}
    follower = {1, 0, 0}
    test_handle_vote_request(candidate, follower, config, true)
  end

  test "test Vote.handle_vote_request() case 0", config do
    # { currentTerm, lastLogTerm, lastLogIndex }
    candidate = {6, 3, 2}
    follower = {4, 1, 2}
    test_handle_vote_request(candidate, follower, config, true)
  end

  test "test Vote.handle_vote_request() case 1", config do
    # { currentTerm, lastLogTerm, lastLogIndex }
    candidate = {6, 3, 1}
    follower = {4, 4, 1}
    test_handle_vote_request(candidate, follower, config, false)
  end

  test "test Vote.handle_vote_request() case 2", config do
    # { currentTerm, lastLogTerm, lastLogIndex }
    candidate = {6, 3, 2}
    follower = {4, 3, 3}
    test_handle_vote_request(candidate, follower, config, false)
  end

  test "test Vote.handle_vote_request() case 3", config do
    # { currentTerm, lastLogTerm, lastLogIndex }
    candidate = {6, 3, 14}
    follower = {4, 3, 10}
    test_handle_vote_request(candidate, follower, config, true)
  end
end
