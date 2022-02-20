defmodule Reply do
  def success(s) do
    %{
      follower: self(),
      term: s.curr_term,
      committed: true,
      request_index: Log.last_index(s)
    }
  end

  def fail(s) do
    %{
      follower: self(),
      term: s.curr_term,
      committed: false,
      request_index: Log.last_index(s)+1
    }
  end

  def not_leader(s) do
    %{
      follower: s.leaderP,
      term: s.curr_term,
      committed: false,
      request_index: nil
    }
  end

  def term(m), do: m.term
  def committed(m), do: m.committed
  def request_index(m), do: m.request_index
  def follower(m), do: m.follower

  def print(m) do
    IO.puts(
      "
      follower: #{inspect(follower(m))},
      term: #{term(m)},
      committed: #{committed(m)},
      request_index: #{request_index(m)}
      "
    )
  end

end #end