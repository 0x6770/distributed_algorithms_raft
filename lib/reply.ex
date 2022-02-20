defmodule Reply do
  def success(s) do
    %{
      follower: self(),
      term: s.curr_term,
      committed: true,
      request_index: s.commit_index
    }
  end

  def fail(s) do
    %{
      follower: self(),
      term: s.curr_term,
      committed: false,
      request_index: s.commit_index+1
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
