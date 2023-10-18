:ok = LocalCluster.start()
[_n1 | _] = LocalCluster.start_nodes("gc-chat-cluster", 2)

IO.puts("Nodes connected count #{Node.list() |> Enum.count()}")
IO.puts("---------------------------------------------------")

chat_type = BenchTest.Global

Benchee.run(
  %{
    "GCChat.Server.send/1" => fn {t, msgs} ->
      GCChat.Server.send(t, msgs)
    end
  },
  time: 10,
  before_scenario: fn x ->
    IO.puts("waitting for #{chat_type}.Server start")
    GCChat.TestFixtures.wait_for_server_started(chat_type)
    IO.puts("#{chat_type}.Server start success!")

    IO.puts(
      "Current scenario is run at [#{inspect(self())}],and #{chat_type}.Server is run at [#{inspect(node(chat_type.server()))}] "
    )

    x
  end,
  before_each: fn x ->
    Process.sleep(10)
    x
  end,
  inputs: %{
    "uniq_10k" => {chat_type, GCChat.TestFixtures.make_uniq_channel_msgs("uniq_10k", 10000)},
    "same_10k" => {chat_type, GCChat.TestFixtures.make_same_channel_msgs("same_10k", 10000)}
  }
)
