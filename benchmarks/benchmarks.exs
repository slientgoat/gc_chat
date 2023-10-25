:ok = LocalCluster.start()
[n1 | _] = LocalCluster.start_nodes("gc-chat-cluster", 2)

IO.puts("Nodes connected count #{Node.list() |> Enum.count()}")
IO.puts("---------------------------------------------------")

create_buffer = fn size ->
  GCChat.TestFixtures.make_same_channel_msgs("same_10k", size)
  |> Enum.reduce({GCChat.Entry.new(size), 0}, fn msg, {acc, i} ->
    last_id = i + 1
    {GCChat.Entry.insert(acc, %{msg | id: last_id}), last_id}
  end)
  |> elem(0)
end

channel = "public"
buffer = create_buffer.(1000)
cache_adapter = GCChat.CacheAdapter.Replicated
cache_adapter.put(channel, buffer)

Benchee.run(
  %{
    # "local lookup newest 500 msgs" => fn input -> GCChat.lookup(cache_adapter, channel, input) end,
    # "rpc.block_call lookup newest 500 msgs" => fn input ->
    #   :rpc.block_call(n1, GCChat, :lookup, [cache_adapter, channel, input])
    # end,
    # "rpc.call lookup newest 500 msgs" => fn input ->
    #   :rpc.call(n1, GCChat, :lookup, [cache_adapter, channel, input])
    # end,
    "rpc.cast lookup newest 500 msgs" => fn input ->
      :rpc.cast(n1, GCChat, :lookup, [cache_adapter, channel, input])
    end
  },
  inputs: %{"newest 500 msgs" => 500}
)
