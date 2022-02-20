# Ko Tsz Wang (twk219) and Yujie Wang (yw2919)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule AppendEntries do
  # s = server process state (c.f. this/self)
  def send_entries_reply_to_leader(s, leaderP, success) do
    Helper.unimplemented([s, leaderP, success])
  end

  def receive_append_entries_request_from_leader(s, m) do
    case s.role do
      :LEADER ->
        s
      :FOLLOWER ->
        #catch up with current term, else remain same
        s =
          cond do
            s.curr_term < Message.term(m) ->
              s
              |> State.curr_term(Message.term(m))
            s.curr_term>= Message.term(m)->
              s
          end

        #check term, check commit
        case check_commit(s,m) do
          :stale ->
            s
          :append ->
            s =
              s
              |> Log.append_entry(Message.entries(m))
              |> State.commit_index(s.commit_index+1)
            send(Message.leaderP(m),{:APPEND_ENTRIES_REPLY,Reply.success(s)})
            s
          :merge ->
            s =
              s
              |> Log.merge_entries(Message.entries(m))
              |> State.commit_index(Message.index(m))
            send(Message.leaderP(m),{:APPEND_ENTRIES_REPLY,Reply.success(s)})
            s
          :request ->
            send(Message.leaderP(m),{:APPEND_ENTRIES_REPLY,Reply.fail(s)})
            s

          :notyet->
            Helper.node_halt(
            "************* Append Entries request from leader: unexpected entry}"
            )
        end

    end
  end

  def receive_append_entries_reply_from_follower(s, m) do
    cond do
      Reply.term(m) < s.curr_term ->
        s
      Reply.committed(m)==true ->
        s
        |> s.next_index(Reply.follower(m),Reply.request_index(m))
      Reply.committed(m)==false ->
        send(Reply.follower(m),Message.log_from(s,Reply.request_index(m)))
        s
    end
  end

  def receive_append_entries_timeout(s, followerP) do
    Helper.unimplemented([s, followerP])
  end

  defp check_commit(s,m) do
    cond do
      Message.term(m) < s.curr_term ->
        :stale
      s.commit_index==Message.last_index(m) ->
        if Log.term_at(s,s.commit_index)==Message.last_term(m) do
          case Message.index(m)==s.commit_index+1 do
            true -> :append
            false -> :merge
          end
        else
          :notyet
        end
      s.commit_index < Message.last_index(m) ->
        :request
      true ->
        :notyet
    end
  end#check_commit

end
