defmodule VoteTest do
  use ExUnit.Case

  def argv do
    [
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
  end

  test "test Vote.handle_election_timeout()" do
    config = Configuration.node_init(argv())
    config = Configuration.node_info(config, "test")
    state = State.initialise(config, 1, [self()], self())

    state |> Vote.handle_election_timeout()

    assert_received {:VOTE_REQUEST, msg}

    {term, candidateId, lastLogIndex, lastLogTerm} = msg

    assert term == 1 + state.curr_term
    assert candidateId == self()
    assert lastLogIndex == Log.last_index(state)
    assert lastLogTerm == Log.last_term(state)
  end
end
