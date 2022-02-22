# Ko Tsz Wang (twk219) and Yujie Wang (yw2919)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule AppendEntries do
  # s = server process state (c.f. this/self)

  @spec send_heartbeat_all(map) :: map
  def send_heartbeat_all(state) do
    List.foldl(state.servers, state, fn server, acc ->
      acc = acc |> Timer.restart_append_entries_timer(server)

      send(
        server,
        {:APPEND_ENTRIES_REQUEST, acc.curr_term, Message.heartbeat(acc)}
      )

      acc
    end)
  end

  def receive_append_entries_request_from_leader(s, m) do
    if m.term < s.curr_term do
      send(m.leaderP, {:APPEND_ENTRIES_REPLY, s.curr_term, Reply.fail(s)})
      s
    else
      s = s |> Timer.restart_election_timer()

      if m.entries |> map_size() == 0 do
        s
        |> Debug.log(
          "my leader is server #{inspect(m.leaderN)}, #{inspect(m.leaderP)}"
        )
      end

      case s.role do
        :CANDIDATE ->
          case s.curr_term <= Message.term(m) do
            true ->
              s
              |> Server.become_follower(m.term, m.leaderP, m.leaderN)
              |> receive_append_entries_request_from_leader(m)

            false ->
              s
          end

        :LEADER ->
          case s.curr_term < Message.term(m) do
            true ->
              s
              |> Server.become_follower(m.term, m.leaderP, m.leaderN)
              |> receive_append_entries_request_from_leader(m)

            false ->
              s
          end

        :FOLLOWER ->
          # catch up with current term, else remain same
          s =
            cond do
              s.curr_term < Message.term(m) ->
                s |> State.curr_term(Message.term(m))

              s.curr_term >= Message.term(m) ->
                s
            end

          # check term, check commit
          case check_commit(s, m) do
            :stale ->
              # TODO put back the stale detection on server
              s

            :merge ->
              s =
                s
                |> Log.merge_entries(Message.entries(m))
                |> State.commit_index(Message.commit_index(m))

              reply = Reply.success(s)

              send(
                Message.leaderP(m),
                {:APPEND_ENTRIES_REPLY, Reply.term(reply), reply}
              )

              s

            :request ->
              reply = Reply.fail(s)

              send(
                Message.leaderP(m),
                {:APPEND_ENTRIES_REPLY, Reply.term(reply), reply}
              )

              s

            :pop ->
              s =
                s
                |> Log.delete_entries_from(Message.last_index(m))

              reply = Reply.fail(s)

              send(
                Message.leaderP(m),
                {:APPEND_ENTRIES_REPLY, Reply.term(reply), reply}
              )

              s

            :repair ->
              s =
                s
                |> Log.delete_entries_from(Message.last_index(m) + 1)
                |> Log.merge_entries(Message.entries(m))
                |> State.commit_index(Message.commit_index(m))

              reply = Reply.success(s)

              send(
                Message.leaderP(m),
                {:APPEND_ENTRIES_REPLY, Reply.term(reply), reply}
              )

              s

            :notyet ->
              Helper.node_halt(
                "************* Append Entries request from leader: unexpected entry}"
              )
          end
      end
    end
  end

  def receive_append_entries_reply_from_follower(s, m) do
    cond do
      Reply.term(m) > s.curr_term ->
        # Reverts to Follower and waits for instructions from leader
        # Let receive do the repair, so log is unchanged here
        s
        |> Server.become_follower(m.term, m.follower, m.followerN)
        |> State.curr_term(Message.term(m))
        |> State.match_index(Map.new())
        |> State.next_index(Map.new())

      Reply.committed(m) == true ->
        s
        |> State.next_index(Reply.follower(m), Reply.request_index(m))
        |> State.match_index(Reply.follower(m), Reply.last_applied(m))
        |> State.set_commit_index()

      Reply.committed(m) == false ->
        msg = Message.log_from(s, Reply.request_index(m))

        send(
          Reply.follower(m),
          {:APPEND_ENTRIES_REQUEST, Message.term(msg), msg}
        )

        s
    end
  end

  def handle_append_entries_timeout(s, followerP) do
    send(
      followerP,
      {:APPEND_ENTRIES_REQUEST, s.curr_term, Message.heartbeat(s)}
    )

    s |> Timer.restart_append_entries_timer(followerP)
  end

  defp check_valid(s, m) do
    Log.term_at(s, Log.last_index(s)) == Message.last_term(m)
  end

  defp check_commit(s, m) do
    cond do
      Message.term(m) < s.curr_term ->
        :stale

      Log.last_index(s) == Message.last_index(m) ->
        if check_valid(s, m) do
          :merge
        else
          :pop
        end

      Log.last_index(s) < Message.last_index(m) ->
        :request

      Log.last_index(s) > Message.last_index(m) ->
        if check_valid(s, m) do
          :repair
        else
          :pop
        end

      true ->
        :notyet
    end
  end
end
