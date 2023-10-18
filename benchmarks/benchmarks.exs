:ok = LocalCluster.start()
[n1 | _] = LocalCluster.start_nodes("gc-chat-cluster", 2)

IO.puts("Nodes connected count #{Node.list() |> Enum.count()}")
IO.puts("---------------------------------------------------")

create_buffer = fn x ->
  Enum.to_list(1..x)
  |> Enum.reduce(CircularBuffer.new(x), fn i, acc ->
    CircularBuffer.insert(acc, i)
  end)
end

channel = "public"
buffer = GCChat.Server.create_buffer(1000)
GCChat.HordeCache.put(channel, buffer)
Process.sleep(1000)
GCChat.HordeCache.get(channel) |> IO.inspect(label: "HordeCache")

GCChat.LocalCache.put(channel, buffer)
GCChat.LocalCache.get(channel) |> IO.inspect(label: "LocalCache")

hander_pid = GCChat.Handler.via_tuple(GCChat.Handler) |> GenServer.whereis()

node(hander_pid) |> IO.inspect(label: "GCChat.Handler.Node")

Benchee.run(%{
  "local lookup newest 500 msgs" => fn -> GCChat.lookup(500) end,
  "local lookup newest 500 msgs" => fn -> GCChat.lookup(500) end,
  "rpc.block_call lookup newest 500 msgs" => fn ->
    :rpc.block_call(n1, GCChat, :lookup, [500])
  end,
  "rpc.call lookup newest 500 msgs" => fn -> :rpc.call(n1, GCChat, :lookup, [500]) end,
  "HordeCache.lookup newest 500 msgs" => fn -> GCChat.HordeCache.lookup(channel, 500) end,
  "LocalCache.lookup newest 500 msgs" => fn -> GCChat.LocalCache.lookup(channel, 500) end,
  "GCChat.Router.lookup newest 500 msgs" => fn -> GCChat.Router.lookup(channel, 500) end,
  "GCChat.Router.lookup2 newest 500 msgs" => fn ->
    GCChat.Router.lookup(hander_pid, channel, 500)
  end
})
