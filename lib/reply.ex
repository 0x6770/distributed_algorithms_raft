defmodule Reply do
  def success(s) do
    %{
      follower: self(),
      term: s.curr_term,
      committed: true,
      request_index: s.curr_term
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

end #end
