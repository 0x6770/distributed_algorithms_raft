# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Client do
  # c = client process state (c.f. self/this)

  # ---------- Client setters() ------------------------------------------------
  def seqnum(c, v), do: Map.put(c, :seqnum, v)
  def request(c, v), do: Map.put(c, :request, v)
  def result(c, v), do: Map.put(c, :result, v)
  def leaderP(c, v), do: Map.put(c, :leaderP, v)
  def servers(c, v), do: Map.put(c, :servers, v)

  # ---------- Client.start() --------------------------------------------------
  def start(config, client_num, servers) do
    config =
      config
      |> Configuration.node_info("Client", client_num)
      |> Debug.node_starting()

    Process.send_after(self(), {:CLIENT_TIMELIMIT}, config.client_timelimit)

    # initialise client state variables
    c = %{
      config: config,
      client_num: client_num,
      clientP: self(),
      servers: servers,
      leaderP: nil,
      seqnum: 0,
      request: nil,
      result: nil
    }

    c |> Client.next()
  end

  # start

  # ---------- Client.next() ---------------------------------------------------
  def next(c) do
    # all done
    if c.seqnum == c.config.max_client_requests do
      Helper.node_sleep(
        "Client #{c.client_num} all requests completed = #{c.seqnum}"
      )
    end

    receive do
      {:CLIENT_TIMELIMIT} ->
        Helper.node_sleep(
          "  Client #{c.client_num}, client timelimit reached, tent = #{c.seqnum}"
        )
    after
      c.config.client_request_interval ->
        # from account
        account1 = Enum.random(1..c.config.n_accounts)
        # to account
        account2 = Enum.random(1..c.config.n_accounts)
        amount = Enum.random(1..c.config.max_amount)

        c = Client.seqnum(c, c.seqnum + 1)
        cmd = {:MOVE, amount, account1, account2}
        # unique client id for cmd
        cid = {c.client_num, c.seqnum}

        c =
          c
          |> Client.request(
            {:CLIENT_REQUEST, %{clientP: c.clientP, cid: cid, cmd: cmd}}
          )
          |> Client.send_client_request_receive_reply(cid)

        Client.next(c)
    end
  end

  # ---------- send_client_request_receive_reply() -----------------------------
  def send_client_request_receive_reply(c, cid) do
    c
    |> Client.send_client_request_to_leader()
    |> Client.receive_reply_from_leader(cid)
  end

  # ---------- send_client_request_to_leader() ---------------------------------
  def send_client_request_to_leader(c) do
    # round-robin leader selection
    c =
      if c.leaderP do
        c
      else
        [server | rest] = c.servers

        c =
          c
          |> Client.leaderP(server)
          |> Client.servers(rest ++ [server])

        c
      end

    send(c.leaderP, c.request)
    c
  end

  # ---------- receive_reply_from_leader() -------------------------------------
  def receive_reply_from_leader(c, cid) do
    receive do
      {:CLIENT_REPLY, {m_cid, :NOT_LEADER, leaderP}} when m_cid == cid ->
        c
        |> Client.leaderP(leaderP)
        |> Client.send_client_request_receive_reply(cid)

      {:CLIENT_REPLY, {m_cid, reply, leaderP}} when m_cid == cid ->
        c
        |> Client.result(reply)
        |> Client.seqnum(1 + c.seqnum)
        |> Client.leaderP(leaderP)

      {:CLIENT_REPLY, {m_cid, _reply, _leaderP}} when m_cid < cid ->
        c |> Client.receive_reply_from_leader(cid)

      {:CLIENT_TIMELIMIT} ->
        Helper.node_sleep(
          "  Client #{c.client_num}, client timelimit reached, sent = #{c.seqnum}"
        )

      unexpected ->
        Helper.node_halt(
          "***************** Client: unexpected message #{inspect(unexpected)}"
        )
    after
      c.config.client_reply_timeout ->
        # leader probably crashed, retry with next server
        c
        |> Client.leaderP(nil)
        |> Client.send_client_request_receive_reply(cid)
    end
  end
end
