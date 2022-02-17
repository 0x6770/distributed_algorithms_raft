# Ko Tsz Wang (twk219) and Yujie Wang (yw2919)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Vote do
  # s = server process state (c.f. self/this)

  def send_vote_reply_to_candidate(s, candidateP, votedGranted) do
    Helper.unimplemented([s, candidateP, votedGranted])
  end

  def receive_vote_request_from_candidate(s, mterm, m) do
    Helper.unimplemented([s, mterm, m])
  end

  def receive_vote_reply_from_follower(s, mterm, m) do
    Helper.unimplemented([s, mterm, m])
  end

  def receive_election_timeout(s) do
    Helper.unimplemented([s])
  end
end
