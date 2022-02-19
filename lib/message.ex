defmodule Message do
  @doc"""
  creates a basic message append entry
  """
  def initialise(s,command) do
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
    end #case s.commit
  end #initialise

  def index(m), do: m.index
  def entry(m), do: m.entry
  def last_term(m), do: m.last_term
end #Message
