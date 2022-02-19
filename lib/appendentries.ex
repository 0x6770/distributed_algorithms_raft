# Ko Tsz Wang (twk219) and Yujie Wang (yw2919)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule AppendEntries do
  # s = server process state (c.f. this/self)

  defp check_commit(s,m) do
    if s.commit_index==Message.index(m)-1 and Log.term_at(s,s.commit_index)==Message.last_term(m) do
      # IO.puts(s.commit_index)
      # IO.puts(Message.index(m)-1)
      :append
    else
      :unexpected
    end
  end#check_commit

  def send_entries_reply_to_leader(s, leaderP, success) do
    Helper.unimplemented([s, leaderP, success])
  end

  def receive_append_entries_request_from_leader(s, mterm, m) do
    case s.role do
      :LEADER ->
        s

      :FOLLOWER ->
        s =
          cond do
            s.curr_term < mterm ->
              s
              |> State.curr_term(mterm)
            s.curr_term>=mterm ->
              s
          end

        #check term, check commit
        case check_commit(s,m) do
          :append ->
            s
            |> Log.append_entry(m.entry)
            |> State.commit_index(s.commit_index+1)
          :unexpected ->
            Helper.node_halt(
            "************* Append Entries request from leader: unexpected entry}"
            )
        end

    end
  end

  def receive_append_entries_reply_from_follower(s, mterm, m) do
    Helper.unimplemented([s, mterm, m])
  end

  def receive_append_entries_timeout(s, followerP) do
    Helper.unimplemented([s, followerP])
  end


end
