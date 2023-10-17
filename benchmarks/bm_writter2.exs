:ok = LocalCluster.start()
[_n1 | _] = LocalCluster.start_nodes("gc-chat-cluster", 20)

IO.puts("Nodes connected count #{Node.list() |> Enum.count()}")
IO.puts("---------------------------------------------------")

GCChat.TestFixtures.wait_for_writter_started()

Benchee.run(
  %{
    "GCChat.Writter.write/1" => fn input ->
      GCChat.Writter.write(input)
    end
  },
  time: 10,
  before_scenario: fn x ->
    IO.puts(
      "Current scenario is run at [#{inspect(self())}],and GCChat.Writter is run at [#{inspect(GCChat.Writter.pid())}] "
    )

    x
  end,
  before_each: fn x ->
    Process.sleep(10)
    x
  end,
  inputs: %{
    "uniq_10k" => GCChat.TestFixtures.make_uniq_channel_msgs("uniq_10k", 10000),
    "same_10k" => GCChat.TestFixtures.make_same_channel_msgs("same_10k", 10000)
  }
)
