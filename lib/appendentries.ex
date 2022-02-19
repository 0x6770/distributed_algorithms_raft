# Ko Tsz Wang (twk219) and Yujie Wang (yw2919)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule AppendEntries do
  # s = server process state (c.f. this/self)

  def send_entries_reply_to_leader(s, leaderP, success) do
    Helper.unimplemented([s, leaderP, success])
  end

  def receive_append_entries_request_from_leader(s, mterm, m) do
    IO.puts("received")
    s
  end

  def receive_append_entries_reply_from_follower(s, mterm, m) do
    Helper.unimplemented([s, mterm, m])
  end

  def receive_append_entries_timeout(s, followerP) do
    Helper.unimplemented([s, followerP])
  end

  @doc"""
  creates a basic message append entry
  """
  def create_m(s,command) do

    case s.commit_index do
      index when index == 0 ->
        %{
        index: s.commit_index,
        entry: %{ term: s.curr_term, command: command},
        last_term: 0
        }
      index when index > 0 ->
        %{
          index: s.commit_index,
          entry: %{ term: s.curr_term, command: command},
          last_term: Log.term_at(s,index-1)
        }
      index ->
        Helper.node_halt(
          "************* AppendEntries: unexpected index #{inspect(index)}"
        )
    end
  end #create_m/2


end
