# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule State do
  # s = server process state (c.f. self/this)

  @type state :: map()

  # ---------- State.initialise() ----------------------------------------------
  def initialise(config, server_num, servers, databaseP) do
    # initialise state variables for server
    %{
      # ---------- constants ---------------------------------------------------

      # system configuration parameters (from Helper module)
      config: config,
      # server num (for debugging)
      server_num: server_num,
      # server's process id
      selfP: self(),
      # list of process id's of servers
      servers: servers,
      # no. of servers
      num_servers: length(servers),
      # cluster membership changes are not supported in this implementation
      majority: div(length(servers), 2) + 1,
      # local database - used to send committed entries for execution
      databaseP: databaseP,

      # ---------- elections ---------------------------------------------------

      # one timer for all peers
      election_timer: nil,
      # used to drop old electionTimeout messages and votereplies
      curr_election: 0,
      # num of candidate that been granted vote incl self
      voted_for: nil,
      # set of processes that have voted for candidate incl. candidate
      voted_by: MapSet.new(),
      # one timer for each follower
      append_entries_timers: Map.new(),
      # included in reply to client request
      leaderP: nil,

      # ---------- raft paper state variables ----------------------------------

      # current term incremented when starting election
      curr_term: 0,
      # log of entries, indexed from 1
      log: Log.new(),
      # one of :FOLLOWER, :LEADER, :CANDIDATE
      role: :FOLLOWER,
      # index of highest committed entry in server's log
      commit_index: 0,
      # index of last entry applied to state machine of server
      last_applied: 0,
      # foreach follower, index of follower's last known entry+1
      next_index: Map.new(),
      # index of highest entry known to be replicated at a follower
      match_index: Map.new()
    }
  end

  # ---------- setters for mutable variables -----------------------------------

  # log is implemented in Log module

  def leaderP(s, v), do: Map.put(s, :leaderP, v)
  def election_timer(s, v), do: Map.put(s, :election_timer, v)
  def curr_election(s, v), do: Map.put(s, :curr_election, v)
  def inc_election(s), do: Map.put(s, :curr_election, s.curr_election + 1)
  def voted_for(s, v), do: Map.put(s, :voted_for, v)
  def new_voted_by(s), do: Map.put(s, :voted_by, MapSet.new())

  def add_to_voted_by(s, v),
    do: Map.put(s, :voted_by, MapSet.put(s.voted_by, v))

  def vote_tally(s), do: MapSet.size(s.voted_by)

  def append_entries_timers(s),
    do: Map.put(s, :append_entries_timers, Map.new())

  def append_entries_timer(s, i, v),
    do:
      Map.put(s, :append_entries_timers, Map.put(s.append_entries_timers, i, v))

  def curr_term(s, v), do: Map.put(s, :curr_term, v)
  def inc_term(s), do: Map.put(s, :curr_term, s.curr_term + 1)

  def role(s, v), do: Map.put(s, :role, v)
  def commit_index(s, v), do: Map.put(s, :commit_index, v)
  def last_applied(s, v), do: Map.put(s, :last_applied, v)

  def next_index(s, v), do: Map.put(s, :next_index, v)

  def next_index(s, i, v),
    do: Map.put(s, :next_index, Map.put(s.next_index, i, v))

  def match_index(s, v), do: Map.put(s, :match_index, v)

  def match_index(s, i, v),
    do: Map.put(s, :match_index, Map.put(s.match_index, i, v))

  def init_next_index(s) do
    v = Log.last_index(s) + 1

    new_next_index =
      for server <- s.servers, into: Map.new() do
        {server, v}
      end

    s |> State.next_index(new_next_index)
  end

  def init_match_index(s) do
    new_match_index =
      for server <- s.servers, into: Map.new() do
        {server, 0}
      end

    s |> State.match_index(new_match_index)
  end

  def set_commit_index(state) do
    if state.role==:LEADER do
      histogram = Helper.to_histogram(Map.values(state.next_index))

      commit_index =
        Enum.reduce(histogram, state.commit_index, fn {index, occurence},
                                                      commit_index ->
          case occurence > state.num_servers / 2 and index > commit_index do
            true -> index
            false -> commit_index
          end
        end)

      state
      |> State.commit_index(commit_index)
    else
      state
    end
  end
end
