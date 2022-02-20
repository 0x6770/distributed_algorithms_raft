defmodule VoteTest.HandleVoteReply do
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

  def setup_state({currentTerm, voteTally, numServers}, config) do
    servers =
      1..(numServers - 1)
      |> Enum.to_list()
      |> Enum.map(fn s -> :c.pid(0, 0, s) end)
      |> Enum.concat([self()])

    state =
      State.initialise(config, 0, servers, self())
      |> State.curr_term(currentTerm)

    if voteTally == 0 do
      state
    else
      List.foldl(Enum.to_list(1..voteTally), state, fn n, acc ->
        acc |> State.add_to_voted_by(n)
      end)
    end
  end

  def test_handle_vote_reply(candidate, voteGranted, term, config) do
    cState = setup_state(candidate, config)

    # msg: followerId, voteGranted, follower.curr_term
    msg = %{followerP: self(), voteGranted: voteGranted, term: term}
    Vote.handle_vote_reply(cState, msg)

    if voteGranted do
      assert_received :APPEND_ENTRIES_REQUEST
    end
  end

  test "test setup_state", config do
    curr_term = 5
    voteTally = 2
    numServers = 3
    # { currentTerm, voteTally, servers }
    candidate = {curr_term, voteTally, numServers}

    state = setup_state(candidate, config)
    assert state |> State.vote_tally() == voteTally
    assert state.curr_term == curr_term

    for server <- state.servers do
      if Process.alive?(server) do
        send(server, :testing)
      end
    end

    assert_received(:testing)
  end

  test "test Vote.handle_vote_reply() voteGranted = true", config do
    # { currentTerm, voteTally, servers }
    candidate = {2, 1, 3}
    test_handle_vote_reply(candidate, true, 2, config)
  end
end
