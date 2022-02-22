# Ko Tsz Wang (twk219) and Yujie Wang (yw2919)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2
defmodule Reply do
  def success(s) do
    %{
      follower: self(),
      term: s.curr_term,
      committed: true,
      request_index: Log.last_index(s),
      last_applied: s.last_applied
    }
  end

  def fail(s) do
    %{
      follower: self(),
      term: s.curr_term,
      committed: false,
      request_index: Log.last_index(s) + 1,
      last_applied: s.last_applied
    }
  end

  def not_leader(s) do
    %{
      follower: s.leaderP,
      term: s.curr_term,
      committed: false,
      request_index: nil,
      last_applied: nil
    }
  end

  def term(m), do: m.term
  def committed(m), do: m.committed
  def request_index(m), do: m.request_index
  def follower(m), do: m.follower
  def last_applied(m), do: m.follower

  def print(m) do
    IO.puts("
      follower: #{inspect(follower(m))},
      term: #{term(m)},
      committed: #{committed(m)},
      request_index: #{request_index(m)}
      last_applied: #{last_applied(m)}
      ")
  end
end

# end
