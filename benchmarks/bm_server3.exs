chat_type = BenchTest.Global
GCChat.TestFixtures.add_channel_msgs("Replicated", 1000)

Benchee.run(
  %{
    "GCChat.lookup/1" => fn {cache_adapter, channel, last_id} ->
      GCChat.lookup(cache_adapter, channel, last_id)
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
  before_each: fn x ->
    x
  end,
  inputs: %{
    "one" => {GCChat.CacheAdapter.Replicated, "Replicated", 999},
    "half" => {GCChat.CacheAdapter.Replicated, "Replicated", 500},
    "full" => {GCChat.CacheAdapter.Replicated, "Replicated", 0}
  }
)
