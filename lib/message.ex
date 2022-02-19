defmodule Message do
  @doc"""
  creates a basic message append entry
  """
  def initialise(s,command) do

        %{
          index: s.commit_index,
          entry: %{ term: s.curr_term, command: command},
          last_term: Log.term_at(s,s.commit_index-1)
        }

  end #initialise

  def get(s)do
      %{
        index: s.commit_index,
        entry: Log.entry_at(s, s.commit_index),
        last_term: Log.term_at(s,s.commit_index-1)
      }
  end

  def index(m), do: m.index
  def entry(m), do: m.entry
  def last_term(m), do: m.last_term
  def print(m) do
    IO.puts(
      "Index: #{m.index}
      Entry: #{m.entry}
      Last_term: #{m.last_term}
      ")
  end
end #Message
