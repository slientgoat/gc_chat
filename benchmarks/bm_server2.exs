:ok = LocalCluster.start()
[_n1 | _] = LocalCluster.start_nodes("gc-chat-cluster", 2)

IO.puts("Nodes connected count #{Node.list() |> Enum.count()}")
IO.puts("---------------------------------------------------")

instance = BenchTest.Global

Benchee.run(
  %{
    "GCChat.Server.send/1" => fn {instance, msgs} ->
      GCChat.Server.send(instance, msgs)
    end
  },
  time: 10,
  before_scenario: fn x ->
    IO.puts("waitting for #{instance}.Server start")
    GCChat.TestFixtures.wait_for_server_started(fn -> instance.server() end)
    IO.puts("#{instance}.Server start success!")

    IO.puts(
      "Current scenario is run at [#{inspect(self())}],and #{instance}.Server is run at [#{inspect(node(instance.server()))}] "
    )

    x
  end,
  # before_each: fn x ->
  #   Process.sleep(1)
  #   x
  # end,
  inputs: %{
    # "same_10000" => {instance, GCChat.TestFixtures.make_same_channel_msgs("same_10000", 10000)}
    # "same_1000" => {instance, GCChat.TestFixtures.make_same_channel_msgs("same_1000", 1000)},
    # "same_100" => {instance, GCChat.TestFixtures.make_same_channel_msgs("same_100", 100)},
    # "same_1" => {instance, GCChat.TestFixtures.make_same_channel_msgs("same_1", 1)},
    # "uniq_10000" => {instance, GCChat.TestFixtures.make_uniq_channel_msgs("uniq_10000", 10000)},
    "uniq_1000" => {instance, GCChat.TestFixtures.make_uniq_channel_msgs("uniq_1000", 1000)},
    # "uniq_100" => {instance, GCChat.TestFixtures.make_uniq_channel_msgs("uniq_100", 100)},
    "uniq_1" => {instance, GCChat.TestFixtures.make_uniq_channel_msgs("uniq_1", 1)}
  }
)
