# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Timer do
  # s = server process state (c.f. self/this)

  # ---------------- restart_election_timer() ----------------------------------
  def restart_election_timer(s) do
    s = Timer.cancel_election_timer(s)

    election_timeout = Enum.random(s.config.election_timeout_range)

    election_timer =
      Process.send_after(
        s.selfP,
        {:ELECTION_TIMEOUT, {s.curr_term, s.curr_election}},
        election_timeout
      )

    s
    |> State.election_timer(election_timer)
    |> Debug.message(
      "+etim",
      {{:ELECTION_TIMEOUT, {s.curr_term, s.curr_election}}, election_timeout}
    )
  end

  # ---------------- cancel_election_timer() -----------------------------------
  def cancel_election_timer(s) do
    if s.election_timer do
      Process.cancel_timer(s.election_timer)
    end

    s |> State.election_timer(nil)
  end

  # ---------- restart_append_entries_timer() ----------------------------------
  def restart_append_entries_timer(s, followerP) do
    s = Timer.cancel_append_entries_timer(s, followerP)

    append_entries_timer =
      Process.send_after(
        s.selfP,
        {:APPEND_ENTRIES_TIMEOUT, s.curr_term, followerP},
        s.config.append_entries_timeout
      )

    s
    |> State.append_entries_timer(followerP, append_entries_timer)
    |> Debug.message(
      "+atim",
      {{:APPEND_ENTRIES_TIMEOUT, s.curr_term, followerP},
       s.config.append_entries_timeout}
    )
  end

  # ---------- cancel_append_entries_timer() -----------------------------------
  def cancel_append_entries_timer(s, followerP) do
    if s.append_entries_timers[followerP] do
      Process.cancel_timer(s.append_entries_timers[followerP])
    end

    s |> State.append_entries_timer(followerP, nil)
  end

  # ---------- cancel_all_append_entries_timers() ------------------------------
  def cancel_all_append_entries_timers(s) do
    for followerP <- s.append_entries_timers do
      # mutated result ignored, next statement will reset
      Timer.cancel_append_entries_timer(s, followerP)
    end

    # now reset to Map.new
    s |> State.append_entries_timers()
  end
end
