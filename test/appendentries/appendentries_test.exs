defmodule RaftTest.AppendEntries do
  use ExUnit.Case

  # ***************** Helper Functions **************************

  def get_state(server_num, client_num) do
    argv = [
      "TEST@127.0.0.1",
      "15000",
      "0",
      "none",
      "#{server_num}",
      "#{client_num}",
      "default",
      "cluster_wait",
      self(),
      100..200,
    ]

    config = %{
      node_suffix: Enum.at(argv, 0),
      raft_timelimit: String.to_integer(Enum.at(argv, 1)),
      debug_level: String.to_integer(Enum.at(argv, 2)),
      debug_options: "#{Enum.at(argv, 3)}",
      n_servers: String.to_integer(Enum.at(argv, 4)),
      n_clients: String.to_integer(Enum.at(argv, 5)),
      setup: :"#{Enum.at(argv, 6)}",
      start_function: :"#{Enum.at(argv, 7)}",
      monitorP: Enum.at(argv, 8),
      election_timeout_range: Enum.at(argv, 9)
    }

    config |> Map.merge(Configuration.params(config.setup))

    State.initialise(config, 0, [self()], self())
  end

  def get_requests(s, range) do
    # Leader forwards by 3
    Enum.reduce(range, s, fn i, s ->
      client_request = %{clientP: nil, cid: nil, cmd: :"cmd#{i}"}
      s = ClientReq.handle_client_request(s, client_request)
      assert_received({:CLIENT_REQUEST, 0})
      assert_received({:APPEND_ENTRIES_REQUEST, _term, _message})
      s
    end)
  end

  def make_request(cmd) do
    %{clientP: nil, cid: nil, cmd: cmd}
  end

  def check_log(s, name) do
    IO.puts("")
    IO.puts(name)
    Log.print(s.log)
  end

  # Returns log of leader and follower synced up with 3 logs in term 1
  def term1_Case() do
    # ****************** same as before**************
    follower = get_state(3, 1)
    leader = Server.become_leader(follower)
    assert leader.curr_term == 1

    leader = get_requests(leader, 1..3)

    # Leader sends message to follower, follower replies with fail and requests for new append request
    msg = Message.get(leader)

    follower =
      AppendEntries.receive_append_entries_request_from_leader(follower, msg)

    failed = Reply.fail(follower)
    # Reply.print(failed)
    assert_received({:APPEND_ENTRIES_REPLY, term, reply})
    assert term == Reply.term(reply)
    assert reply == failed
    assert Reply.request_index(failed) == 1

    # Leader sends updated Append Entries request
    leader =
      AppendEntries.receive_append_entries_reply_from_follower(leader, reply)

    assert_received({:APPEND_ENTRIES_REQUEST, term, message})
    assert term == Message.term(message)
    assert message == Message.log_from(leader, Reply.request_index(failed))

    # Message.print(message)
    follower =
      AppendEntries.receive_append_entries_request_from_leader(
        follower,
        message
      )

    success = Reply.success(follower)
    assert_received({:APPEND_ENTRIES_REPLY, term, reply})
    assert term == Reply.term(reply)
    assert reply == success
    assert leader.log == follower.log

    reply = Reply.success(follower)
    # Reply.print(reply)
    leader =
      AppendEntries.receive_append_entries_reply_from_follower(leader, reply)

    assert leader.next_index[self()] == 3
    # Log.print(leader.log)
    # Log.print(follower.log)
    # ****************** same as before**************
    # * now both leader and follower has 3 entries of cmd1,2,3 in term 1
    {follower, leader}
  end

  # def receive_request(follower,leader):
  #   message.get(leader)
  #   follower = AppendEntries.receive_append_entries_request_from_leader(follower,message)

  # ***************** Test Starts here **************************
  test "test Become Leader" do
    follower = get_state(3, 1)
    candidate = Server.become_candidate(follower)
    leader = Server.become_leader(candidate)

    assert leader.role == :LEADER
    assert leader.curr_term == 1
  end

  test "test Message.initialise(s,cmd)" do
    follower = get_state(3, 1)
    candidate = Server.become_candidate(follower)
    leader = Server.become_leader(candidate)
    leader = ClientReq.handle_client_request(leader, make_request(:cmd1))
    m = Message.get(leader)

    assert m ==
     %{
      entries: %{1 => %{term: 0, client_request: %{cid: nil, clientP: nil, cmd: :cmd1}}},
      index: 1,
      last_index: 0,
      last_term: 0,
      leaderP: self(),
      term: 1,
      leaderN: 0
      }

  end

  test "test handle_client_request (case leader)" do
    follower = get_state(3, 1)
    candidate = Server.become_candidate(follower)
    leader = Server.become_leader(follower)
    assert leader.curr_term == 1
    leader_after = ClientReq.handle_client_request(leader, make_request(:cmd1))

    m = Message.initialise(leader_after, :cmd1)
    assert_received({:APPEND_ENTRIES_REQUEST, term, got})
    assert term == Message.term(got)
    assert got == m
    assert Log.entry_at(leader_after, 1) == %{term: 1, command: :cmd1}
    assert Log.last_index(leader_after) == 1
  end

  test "test receive_append, basic" do
    follower = get_state(3, 1)
    candidate = Server.become_candidate(follower)
    leader = Server.become_leader(candidate)
    assert leader.curr_term == 1

    leader = ClientReq.handle_client_request(leader, make_request(:cmd1))

    msg = Message.get(leader)

    follower =
      AppendEntries.receive_append_entries_request_from_leader(follower, msg)

    success = Reply.success(follower)
    assert_received({:APPEND_ENTRIES_REPLY, term, reply})
    assert term == Reply.term(reply)
    assert reply == success

    assert Log.last_index(follower) == 1
    # IO.puts("follower")
    # Log.print(follower.log)
    # IO.puts("Leader")
    # Log.print(leader.log)
    assert Log.last_index(follower) == 1
    assert Log.entry_at(follower, 1) == Log.entry_at(leader, 1)

    leader =
      AppendEntries.receive_append_entries_reply_from_follower(leader, success)

    assert leader.next_index[self()] == 1
  end

  test "test append follower, stale request" do
    follower = get_state(3, 1)
    candidate = Server.become_candidate(follower)
    leader = Server.become_leader(candidate)
    assert leader.curr_term == 1

    # TO BE DONE
  end

  test "test append follower, reply fail and request" do
    follower = get_state(3, 1)
    candidate = Server.become_candidate(follower)
    leader = Server.become_leader(candidate)
    assert leader.curr_term == 1

    leader = get_requests(leader, 1..3)

    msg = Message.get(leader)

    follower =
      AppendEntries.receive_append_entries_request_from_leader(follower, msg)

    failed = Reply.fail(follower)
    assert_received({:APPEND_ENTRIES_REPLY, term, reply})
    assert term == Reply.term(reply)
    assert reply == failed
  end

  test "test append follower, :request + :merge" do
    follower = get_state(3, 1)
    candidate = Server.become_candidate(follower)
    leader = Server.become_leader(candidate)
    assert leader.curr_term == 1

    # Leader forwards by 3
    leader = get_requests(leader, 1..3)
    # IO.puts("leader before")
    # Log.print(leader.log)
    # IO.puts("follower before")
    # Log.print(follower.log)

    # Leader sends message to follower, follower replies with fail and requests for new append request
    msg = Message.get(leader)

    follower =
      AppendEntries.receive_append_entries_request_from_leader(follower, msg)

    failed = Reply.fail(follower)
    # Reply.print(failed)
    assert_received({:APPEND_ENTRIES_REPLY, term, reply})
    assert term == Reply.term(reply)
    assert reply == failed
    assert Reply.request_index(failed) == 1

    # Leader sends updated Append Entries request
    leader =
      AppendEntries.receive_append_entries_reply_from_follower(leader, reply)

    assert_received({:APPEND_ENTRIES_REQUEST, term, message})
    assert term == Message.term(message)
    assert message == Message.log_from(leader, Reply.request_index(failed))

    # Message.print(message)
    follower =
      AppendEntries.receive_append_entries_request_from_leader(
        follower,
        message
      )

    success = Reply.success(follower)
    assert_received({:APPEND_ENTRIES_REPLY, term, reply})
    assert term == Reply.term(reply)
    assert reply == success
    assert leader.log == follower.log

    reply = Reply.success(follower)
    # Reply.print(reply)
    leader =
      AppendEntries.receive_append_entries_reply_from_follower(leader, reply)

    assert leader.next_index[self()] == 3
    check_log(leader, "leader")
    check_log(follower, "followerhandle_client_request")

    for {key, value} <- leader.next_index do
      IO.puts("#{inspect(key)} => #{value}")
    end
  end

  test "test :pop append with excess entry" do
    # ****************** same as before**************
    follower = get_state(3, 1)
    candidate = Server.become_candidate(follower)
    leader = Server.become_leader(candidate)
    assert leader.curr_term == 1

    leader = get_requests(leader, 1..3)

    # Leader sends message to follower, follower replies with fail and requests for new append request
    msg = Message.get(leader)

    follower =
      AppendEntries.receive_append_entries_request_from_leader(follower, msg)

    failed = Reply.fail(follower)
    # Reply.print(failed)
    assert_received({:APPEND_ENTRIES_REPLY, term, reply})
    assert term == Reply.term(reply)
    assert reply == failed
    assert Reply.request_index(failed) == 1

    # Leader sends updated Append Entries request
    leader =
      AppendEntries.receive_append_entries_reply_from_follower(leader, reply)

    assert_received({:APPEND_ENTRIES_REQUEST, term, message})
    assert term == Message.term(message)
    assert message == Message.log_from(leader, Reply.request_index(failed))

    # Message.print(message)
    follower =
      AppendEntries.receive_append_entries_request_from_leader(
        follower,
        message
      )

    success = Reply.success(follower)
    assert_received({:APPEND_ENTRIES_REPLY, term, reply})
    assert term == Reply.term(reply)
    assert reply == success
    assert leader.log == follower.log

    reply = Reply.success(follower)
    # Reply.print(reply)
    leader =
      AppendEntries.receive_append_entries_reply_from_follower(leader, reply)

    assert leader.next_index[self()] == 3
    # Log.print(leader.log)
    # Log.print(follower.log)
    # ****************** same as before**************
    # * now both leader and follower has 3 entries of cmd1,2,3 in term 1

    # new leader elected
    leader = Server.become_leader(follower)
    assert leader.curr_term == 2
    leader = Log.delete_entries_from(leader, 2)

    leader =
      leader
      |> get_requests(4..5)
      |> State.next_index(2)
      |> State.match_index(1)

    # check_log(leader,"leader")
    # check_log(follower,"follower")

    # set-up
    # leader
    # 1: {1, cmd1}
    # 2: {2, cmd4}
    # 3: {2, cmd5}

    # follower
    # 1: {1, cmd1}
    # 2: {1, cmd2}
    # 3: {1, cmd3}

    # From Client request leader sents message
    message = Message.get(leader)
    # Message.print(message)

    # Follower receives Message and responds asking for entry from last_index
    # Follower pops all entries after last_index
    follower =
      AppendEntries.receive_append_entries_request_from_leader(
        follower,
        message
      )

    fail = Reply.fail(follower)
    assert_received({:APPEND_ENTRIES_REPLY, term, reply})
    assert term == Reply.term(reply)
    assert reply == fail
    # Reply.print(reply)
    assert Log.last_index(follower) == 1
    # check_log(follower,"follower")

    # Leader provides logs from index requested
    leader =
      AppendEntries.receive_append_entries_reply_from_follower(leader, reply)

    message = Message.log_from(leader, Reply.request_index(reply))
    assert_received({:APPEND_ENTRIES_REQUEST, term, msg})
    assert term == Message.term(msg)
    assert msg == message
    # check_log(leader,"leader")
    # check_log(follower,"follower")

    # Follower appends entries from leader and returns with success
    follower =
      AppendEntries.receive_append_entries_request_from_leader(
        follower,
        message
      )

    success = Reply.success(follower)
    assert_received({:APPEND_ENTRIES_REPLY, term, reply})
    assert term == Reply.term(reply)
    assert reply == success
    assert Log.last_index(follower) == 3
  end

  test "test check_commitiable" do
    x = [1, 1, 2, 3, 4, 5, 5, 5, 7]

    res = %{
      1 => 2,
      2 => 1,
      3 => 1,
      4 => 1,
      5 => 3,
      7 => 1
    }

    hist = Helper.to_histogram(x)
    assert hist == res

    server = get_state(5, 1)
    server = Server.become_leader(server)
    log =
    %{
      1 => %{term: 1, req: :cmd1},
      2 => %{term: 1, req: :cmd2},
      3 => %{term: 1, req: :cmd3},
      4 => %{term: 1, req: :cmd4},
      5 => %{term: 1, req: :cmd5}
    }
    res = %{
      1 => 2,
      2 => 3,
      3 => 2,
      4 => 2,
      5 => 1
    }

    server =
      server
      |> Map.put(:num_servers, 5)
      |> State.next_index(res)
      |> State.set_commit_index()

    assert server.commit_index == 2
  end

  test "test commit_client_request" do
    follower = get_state(3, 1)
    candidate = Server.become_candidate(follower)
    leader = Server.become_leader(candidate)
    assert leader.curr_term == 1

    indices = %{
      1 => 2,
      2 => 3,
      3 => 2,
      4 => 2,
      5 => 1
    }

    # Leader forwards by 3
    leader = get_requests(leader, 1..3)
    assert leader.commit_index == 0

    leader =
      leader
      |> Map.put(:num_servers, 5)
      |> State.next_index(indices)

    assert leader.commit_index == 0

    leader =
      leader
      |> Server.execute_committed_entries()

    assert leader.commit_index == 2
    assert leader.last_applied == leader.commit_index
    assert_received({:DB_REQUEST, client_request1})
    assert_received({:DB_REQUEST, client_request2})
    assert client_request1 == :cmd1
    assert client_request2 == :cmd2
  end

  # test "test send entry reply to old leader"do
  #   {follower,leader} = term1_Case()

  #   leader = get_requests(leader,4..5)
  #   new_leader = Server.become_leader(follower)
  #   new_leader = get_requests(new_leader,6..7)
  #   follower = Server.become_follower(new_leader,2)

  #   check_log(new_leader,"new leader")
  #   check_log(leader,"old leader")
  #   check_log(follower,"follower")

  #   Message.get(new leader)

  # end
end
