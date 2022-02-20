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

  test "test Message.initialise(s,cmd)" do
    follower = get_state(3,1)
    leader = Server.become_leader(follower)
    leader = ClientReq.receive_request_from_client(leader,:cmd1)
    m = Message.get(leader)
    assert m==
      %{
      leaderP: self(),
      term: 1,
      index: 1,
      entries: %{ term: 1, command: :cmd1},
      last_index: 0,
      last_term: 0
      }
  end

  test "test Receive_request_from_client (case leader)" do
    follower = get_state(3,1)
    leader = Server.become_leader(follower)
    assert leader.curr_term==1
    leader_after = ClientReq.receive_request_from_client(leader,:cmd1)

    m = Message.initialise(leader_after,:cmd1)
    assert_received({:APPEND_ENTRIES_REQUEST, got})
    assert got==m
    assert Log.entry_at(leader_after,1)==%{term: 1,command: :cmd1}
    assert leader_after.commit_index==1
  end

  test "test receive_append, basic" do
    follower = get_state(3,1)
    leader = Server.become_leader(follower)
    assert leader.curr_term==1

    leader = ClientReq.receive_request_from_client(leader,:cmd1)

    msg = Message.get(leader)

    follower = AppendEntries.receive_append_entries_request_from_leader(follower,msg)
    success = Reply.success(follower)
    assert_received({:APPEND_ENTRIES_REPLY, reply})
    assert reply==success

    assert follower.commit_index==1
    # IO.puts("follower")
    # Log.print(follower.log)
    # IO.puts("Leader")
    # Log.print(leader.log)
    assert Log.last_index(follower)==1
    assert Log.entry_at(follower,1)==Log.entry_at(leader,1)
  end

  test "test append follower, stale request" do
    follower = get_state(3,1)
    leader = Server.become_leader(follower)
    assert leader.curr_term==1

    #TO BE DONE
  end


  test "test append follower, reply fail and request" do
    follower = get_state(3,1)
    leader = Server.become_leader(follower)
    assert leader.curr_term==1

    leader = ClientReq.receive_request_from_client(leader,:cmd1)
    leader = ClientReq.receive_request_from_client(leader,:cmd2)
    leader = ClientReq.receive_request_from_client(leader,:cmd3)

    msg = Message.get(leader)

    follower = AppendEntries.receive_append_entries_request_from_leader(follower,msg)
    failed = Reply.fail(follower)
    assert_received({:APPEND_ENTRIES_REPLY, reply})
    assert reply==failed


  end

  test "test append follower, append multiple" do
    follower = get_state(3,1)
    leader = Server.become_leader(follower)
    assert leader.curr_term==1

    leader = ClientReq.receive_request_from_client(leader,:cmd1)
    leader = ClientReq.receive_request_from_client(leader,:cmd2)
    leader = ClientReq.receive_request_from_client(leader,:cmd3)
    IO.puts("leader before")
    Log.print(leader.log)
    IO.puts("follower before")
    Log.print(follower.log)
    msg = Message.get(leader)

    follower = AppendEntries.receive_append_entries_request_from_leader(follower,msg)
    failed = Reply.fail(follower)
    assert_received({:APPEND_ENTRIES_REPLY, reply})
    assert reply==failed
    assert Reply.request_index(failed)==1

    leader = AppendEntries.receive_append_entries_reply_from_follower(leader,reply)
    assert_received({:APPEND_ENTRIES_REQUEST, message})
    assert message = Message.log_from(leader,Reply.request_index(failed))

    follower = AppendEntries.receive_append_entries_request_from_leader(follower,message)
    success = Reply.success(follower)
    assert_received({:APPEND_ENTRIES_REPLY, reply})
    assert reply==success
    assert leader.log==follower.log
    Log.print(leader.log)
    Log.print(follower.log)
  end

  test "test append with excess entry" do
    #TOBE DONE
  end

end
