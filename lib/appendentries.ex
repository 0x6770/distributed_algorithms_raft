# Ko Tsz Wang (twk219) and Yujie Wang (yw2919)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule AppendEntries do
  # s = server process state (c.f. this/self)

  def send_entries_reply_to_leader(s, leaderP, success) do
    Helper.unimplemented([s, leaderP, success])
  end

  def receive_append_entries_request_from_leader(s, mterm, m) do
    # m.index
    # case s.role do
    #   :LEADER ->
    #     s

    #   :FOLLOWER ->
    #     #check term, check commit
    #     case {s.commit_index , Log.term_at(s.commit_index)} do
    #       { (m.index-1), m.last_term} ->
    #         s
    #         |> Log.append_entry(m.entry)
    #         |> State.commit_index(s.commit_index+1)
    #       unexpected ->
    #         Helper.node_halt(
    #         "************* AppendEtries request from leader: unexpected message #{inspect(unexpected)}"
    #       )
    #     end

    # end
  end

  def receive_append_entries_reply_from_follower(s, mterm, m) do
    Helper.unimplemented([s, mterm, m])
  end

  def receive_append_entries_timeout(s, followerP) do
    Helper.unimplemented([s, followerP])
  end


end
