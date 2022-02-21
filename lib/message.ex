defmodule Message do
  @doc"""
  creates a basic message append entry
  """
  def initialise(s,command) do
        %{
          leaderP: self(),
          term: s.curr_term,
          index: Log.last_index(s),
          entries: %{ Log.last_index(s) => %{ term: s.curr_term, command: command}},
          last_index: Log.last_index(s)-1,
          last_term: Log.term_at(s,Log.last_index(s)-1)
        }

  end #initialise

  def heartbeat(s) do
    %{
      leaderP: self(),
      term: s.curr_term,
      index: Log.last_index(s),
      entries: %{},
      last_index: 0,
      last_term: 0
    }
end #initialise

  def log_from(s,index) do
    %{
      leaderP: self(),
      term: s.curr_term,
      index: Log.last_index(s),
      entries: Log.get_entries(s,index..Log.last_index(s)),
      last_index: index-1,
      last_term: Log.term_at(s,index-1)
    }
  end

  def get(s)do
      %{
        leaderP: self(),
        term: s.curr_term,
        index: Log.last_index(s),
        entries: %{Log.last_index(s) => Log.entry_at(s, Log.last_index(s))},
        last_index: Log.last_index(s)-1,
        last_term: Log.term_at(s,Log.last_index(s)-1)
      }
  end

  def leaderP(m), do: m.leaderP
  def term(m),do: m.term
  def index(m), do: m.index
  def entries(m), do: m.entries
  def last_index(m), do: m.last_index
  def last_term(m), do: m.last_term

  def print(m) do
    IO.puts(
"LeaderP: #{inspect{m.leaderP}}
Term: #{m.term}
Index: #{m.index}
Entry:")
Log.print(m.entries)
IO.puts("
Last_index: #{m.last_index}
Last_term: #{m.last_term}
")
  end
end #Message
