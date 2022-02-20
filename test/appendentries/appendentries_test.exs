defmodule RaftTest.AppendEntries do
  use ExUnit.Case

  #***************** Helper Functions **************************

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

  def get_requests(s,range) do
    #Leader forwards by 3
    Enum.reduce(range,s,fn i,s ->
      s = ClientReq.receive_request_from_client(s,:"cmd#{i}")
      assert_received({:APPEND_ENTRIES_REQUEST, _term,_message})
      s
    end)
  end

  def check_log(s,name) do
    IO.puts("")
    IO.puts(name)
    Log.print(s.log)

  end

#***************** Test Starts here **************************
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
      entries: %{1 => %{ term: 1, command: :cmd1}},
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
    assert_received({:APPEND_ENTRIES_REQUEST,term, got})
    assert term==Message.term(got)
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
    assert_received({:APPEND_ENTRIES_REPLY,term, reply})
    assert term==Reply.term(reply)
    assert reply==success

    assert follower.commit_index==1
    # IO.puts("follower")
    # Log.print(follower.log)
    # IO.puts("Leader")
    # Log.print(leader.log)
    assert Log.last_index(follower)==1
    assert Log.entry_at(follower,1)==Log.entry_at(leader,1)
    leader = AppendEntries.receive_append_entries_reply_from_follower(leader,success)
    assert leader.next_index[self()]==1
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

    leader = get_requests(leader,1..3)

    msg = Message.get(leader)

    follower = AppendEntries.receive_append_entries_request_from_leader(follower,msg)
    failed = Reply.fail(follower)
    assert_received({:APPEND_ENTRIES_REPLY,term, reply})
    assert term==Reply.term(reply)
    assert reply==failed


  end

  test "test append follower, append multiple" do
    follower = get_state(3,1)
    leader = Server.become_leader(follower)
    assert leader.curr_term==1

    #Leader forwards by 3
    leader = get_requests(leader,1..3)
    # IO.puts("leader before")
    # Log.print(leader.log)
    # IO.puts("follower before")
    # Log.print(follower.log)

    # Leader sends message to follower, follower replies with fail and requests for new append request
    msg = Message.get(leader)
    follower = AppendEntries.receive_append_entries_request_from_leader(follower,msg)
    failed = Reply.fail(follower)
    # Reply.print(failed)
    assert_received({:APPEND_ENTRIES_REPLY,term, reply})
    assert term==Reply.term(reply)
    assert reply==failed
    assert Reply.request_index(failed)==1

    #Leader sends updated Append Entries request
    leader = AppendEntries.receive_append_entries_reply_from_follower(leader,reply)
    assert_received({:APPEND_ENTRIES_REQUEST,term, message})
    assert term==Message.term(message)
    assert message == Message.log_from(leader,Reply.request_index(failed))

    # Message.print(message)
    follower = AppendEntries.receive_append_entries_request_from_leader(follower,message)
    success = Reply.success(follower)
    assert_received({:APPEND_ENTRIES_REPLY, term, reply})
    assert term==Reply.term(reply)
    assert reply==success
    assert leader.log==follower.log

    reply = Reply.success(follower)
    # Reply.print(reply)
    leader = AppendEntries.receive_append_entries_reply_from_follower(leader,reply)
    assert leader.next_index[self()]==3
    # Log.print(leader.log)
    # Log.print(follower.log)
  end

  test "test append with excess entry" do
    #****************** same as before**************
    follower = get_state(3,1)
    leader = Server.become_leader(follower)
    assert leader.curr_term==1

    leader=get_requests(leader,1..3)

    # Leader sends message to follower, follower replies with fail and requests for new append request
    msg = Message.get(leader)
    follower = AppendEntries.receive_append_entries_request_from_leader(follower,msg)
    failed = Reply.fail(follower)
    # Reply.print(failed)
    assert_received({:APPEND_ENTRIES_REPLY,term, reply})
    assert term==Reply.term(reply)
    assert reply==failed
    assert Reply.request_index(failed)==1

    #Leader sends updated Append Entries request
    leader = AppendEntries.receive_append_entries_reply_from_follower(leader,reply)
    assert_received({:APPEND_ENTRIES_REQUEST,term, message})
    assert term==Message.term(message)
    assert message == Message.log_from(leader,Reply.request_index(failed))

    # Message.print(message)
    follower = AppendEntries.receive_append_entries_request_from_leader(follower,message)
    success = Reply.success(follower)
    assert_received({:APPEND_ENTRIES_REPLY,term, reply})
    assert term==Reply.term(reply)
    assert reply==success
    assert leader.log==follower.log

    reply = Reply.success(follower)
    # Reply.print(reply)
    leader = AppendEntries.receive_append_entries_reply_from_follower(leader,reply)
    assert leader.next_index[self()]==3
    # Log.print(leader.log)
    # Log.print(follower.log)
    #****************** same as before**************
    #* now both leader and follower has 3 entries of cmd1,2,3 in state 1

    #new leader elected
    leader=Server.become_leader(follower)
    assert leader.curr_term==2
    leader=Log.delete_entries_from(leader, 2)
    leader=State.commit_index(leader,1)
    leader=
      leader
      |> get_requests(4..5)
      |> State.next_index(2)
      |> State.match_index(1)

    # check_log(leader,"leader")
    # check_log(follower,"follower")
    assert Log.last_index(leader)==leader.commit_index

    # set-up
    # leader
    # 1: {1, cmd1}
    # 2: {2, cmd4}
    # 3: {2, cmd5}

    # follower
    # 1: {1, cmd1}
    # 2: {1, cmd2}
    # 3: {1, cmd3}

    #From Client request leader sents message
    message = Message.get(leader)
    # Message.print(message)

    # Follower receives Message and responds asking for entry from last_index
    # Follower pops all entries after last_index
    follower = AppendEntries.receive_append_entries_request_from_leader(follower,message)
    fail = Reply.fail(follower)
    assert_received({:APPEND_ENTRIES_REPLY,term, reply})
    assert term==Reply.term(reply)
    assert reply==fail
    # Reply.print(reply)
    assert follower.commit_index==1
    # check_log(follower,"follower")

    #Leader provides logs from index requested
    leader = AppendEntries.receive_append_entries_reply_from_follower(leader,reply)
    message = Message.log_from(leader,Reply.request_index(reply))
    assert_received({:APPEND_ENTRIES_REQUEST, term, msg})
    assert term==Message.term(msg)
    assert msg==message
    # check_log(leader,"leader")
    # check_log(follower,"follower")

    #Follower appends entries from leader and returns with success
    follower = AppendEntries.receive_append_entries_request_from_leader(follower,message)
    success = Reply.success(follower)
    assert_received({:APPEND_ENTRIES_REPLY,term, reply})
    assert term==Reply.term(reply)
    assert reply==success
    assert follower.commit_index==3


  end

end
