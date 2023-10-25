:ok = LocalCluster.start()
[_n1 | _] = LocalCluster.start_nodes("gc-chat-cluster", 2)

IO.puts("Nodes connected count #{Node.list() |> Enum.count()}")
IO.puts("---------------------------------------------------")

chat_type = BenchTest.Global

Benchee.run(
  %{
    "GCChat.Server.send/1" => fn {chat_type, msgs} ->
      GCChat.Server.send(chat_type, msgs)
    end
  },
  time: 10,
  before_scenario: fn x ->
    IO.puts("waitting for #{chat_type}.Server start")
    GCChat.TestFixtures.wait_for_server_started(fn -> chat_type.server() end)
    IO.puts("#{chat_type}.Server start success!")

    IO.puts(
      "Current scenario is run at [#{inspect(self())}],and #{chat_type}.Server is run at [#{inspect(node(chat_type.server()))}] "
    )

    x
  end,
  # before_each: fn x ->
  #   Process.sleep(1)
  #   x
  # end,
  inputs: %{
    # "same_10000" => {chat_type, GCChat.TestFixtures.make_same_channel_msgs("same_10000", 10000)}
    # "same_1000" => {chat_type, GCChat.TestFixtures.make_same_channel_msgs("same_1000", 1000)},
    # "same_100" => {chat_type, GCChat.TestFixtures.make_same_channel_msgs("same_100", 100)},
    # "same_1" => {chat_type, GCChat.TestFixtures.make_same_channel_msgs("same_1", 1)},
    # "uniq_10000" => {chat_type, GCChat.TestFixtures.make_uniq_channel_msgs("uniq_10000", 10000)},
    "uniq_1000" => {chat_type, GCChat.TestFixtures.make_uniq_channel_msgs("uniq_1000", 1000)},
    # "uniq_100" => {chat_type, GCChat.TestFixtures.make_uniq_channel_msgs("uniq_100", 100)},
    "uniq_1" => {chat_type, GCChat.TestFixtures.make_uniq_channel_msgs("uniq_1", 1)}
  }
)
