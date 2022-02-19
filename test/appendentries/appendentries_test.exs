defmodule RaftTest.AppendEntries do
  use ExUnit.Case

  # def add1(num) do
  #   num + 1
  # end

  # test "test add1" do
  #   assert add1(4) == 5
  # end



  # test "Case Statement" do
  #   x = 4
  #   case x do
  #     3 -> IO.puts("x=3")
  #     _ -> IO.puts("not 3")
  #   end
  # end

  def get_state(server_num,client_num) do
    argv = [
      "TEST@127.0.0.1",
      "15000",
      "0",
      "none",
      "#{server_num}",
      "#{client_num}",
      "default",
      "cluster_wait"
    ]

    config = %{
      node_suffix: Enum.at(argv,0),
      raft_timelimit: String.to_integer(Enum.at(argv,1)),
      debug_level: String.to_integer(Enum.at(argv,2)),
      debug_options: "#{Enum.at(argv,3)}",
      n_servers: String.to_integer(Enum.at(argv,4)),
      n_clients: String.to_integer(Enum.at(argv,5)),
      setup: :"#{Enum.at(argv,6)}",
      start_function: :"#{Enum.at(argv,7)}"
    }

    config |> Map.merge(Configuration.params(config.setup))

    State.initialise(config,0, [self()], self())
  end

  test "test Become Leader" do
    s = get_state(3,1)
    s = Server.become_leader(s)

    assert s.role==:LEADER
    assert s.curr_term==1
  end

  test "test create_m" do
    follower = get_state(3,1)
    leader = Server.become_leader(follower)
    m = AppendEntries.create_m(leader,:command)
    assert m =
      %{
      index: 0,
      entry: %{ term: 1, entry: :command},
      last_term: 0
      }
  end

  test "test Receive_request_from_client (case leader)" do
    follower = get_state(3,1)
    leader = Server.become_leader(follower)
    assert leader.curr_term==1
    leader_after = ClientReq.receive_request_from_client(leader,:cmd1)

    m = AppendEntries.create_m(leader,:cmd1)
    assert_received({:APPEND_ENTRIES_REQUEST, 1, m})
    assert Log.entry_at(leader_after,1)==%{term: 1,command: :cmd1}
    assert leader_after.commit_index==1
  end

end
