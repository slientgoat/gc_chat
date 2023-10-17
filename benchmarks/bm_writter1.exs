uniq_10k = GCChat.TestFixtures.make_uniq_channel_msgs("uniq_10k", 10000)
same_10k = GCChat.TestFixtures.make_same_channel_msgs("same_10k", 10000)
buffers1 = GCChat.Writter.write_msgs(%{}, uniq_10k)
buffers2 = GCChat.Writter.write_msgs(%{}, same_10k)

Benchee.run(
  %{
    "write 10k msgs with uniq channel" => fn -> GCChat.Writter.write_msgs(buffers1, uniq_10k) end,
    "write 10k msgs with same channel" => fn -> GCChat.Writter.write_msgs(buffers2, same_10k) end
  },
  time: 10
)
