# Ko Tsz Wang (twk219) and Yujie Wang (yw2919)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2
defmodule Message do
  @doc """
  creates a basic message append entry
  """
  def initialise(s, client_request) do
    %{
      leaderP: s.selfP,
      leaderN: s.server_num,
      term: s.curr_term,
      index: Log.last_index(s),
      entries: %{
        Log.last_index(s) => %{
          term: s.curr_term,
          client_request: client_request
        }
      },
      last_index: Log.last_index(s) - 1,
      last_term: Log.term_at(s, Log.last_index(s) - 1),
      commit_index: s.commit_index
    }
  end

  def heartbeat(s) do
    %{
      leaderP: s.selfP,
      leaderN: s.server_num,
      term: s.curr_term,
      index: Log.last_index(s),
      entries: Map.new(),
      last_index: Log.last_index(s),
      last_term: Log.last_term(s),
      commit_index: s.commit_index
    }
  end

  def log_from(s, index) do
    %{
      leaderP: s.selfP,
      leaderN: s.server_num,
      term: s.curr_term,
      index: Log.last_index(s),
      entries: Log.get_entries(s, index..Log.last_index(s)),
      last_index: index - 1,
      last_term: Log.term_at(s, index - 1),
      commit_index: s.commit_index
    }
  end

  def get(s) do
    %{
      leaderP: s.selfP,
      leaderN: s.server_num,
      term: s.curr_term,
      index: Log.last_index(s),
      entries: %{Log.last_index(s) => Log.entry_at(s, Log.last_index(s))},
      last_index: Log.last_index(s) - 1,
      last_term: Log.term_at(s, Log.last_index(s) - 1)
    }
  end

  def leaderP(m), do: m.leaderP
  def term(m), do: m.term
  def index(m), do: m.index
  def entries(m), do: m.entries
  def last_index(m), do: m.last_index
  def last_term(m), do: m.last_term
  def commit_index(m), do: m.commit_index

  def print(m) do
    IO.puts("LeaderP: #{inspect({m.leaderP})}
Term: #{m.term}
Index: #{m.index}
Entry:")
    Log.print(m.entries)
    IO.puts("
Last_index: #{m.last_index}
Last_term: #{m.last_term}
Commit_index: #{m.commit_index}
")
  end
end
