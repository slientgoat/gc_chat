import GCChat.TestFixtures
buffer_size = 1000

uniq_channel_input = fn prefix, num ->
  msgs = make_uniq_channel_msgs(prefix, num)
  buffers1 = GCChat.Server.write_msgs(%{}, msgs, buffer_size)
  {buffers1, msgs}
end

same_channel_input = fn prefix, num ->
  msgs = make_same_channel_msgs(prefix, num)
  buffers1 = GCChat.Server.write_msgs(%{}, msgs, buffer_size)
  {buffers1, msgs}
end

Benchee.run(
  %{
    "GCChat.Server.write_msgs/2" => fn {buffers, msgs} ->
      GCChat.Server.write_msgs(buffers, msgs, buffer_size)
    end
  },
  inputs: %{
    "uniq_10k" => uniq_channel_input.("uniq_10k", 10000),
    "uniq_200" => uniq_channel_input.("uniq_200", 200),
    "same_10k" => same_channel_input.("same_10k", 10000),
    "same_200" => same_channel_input.("same_200", 200)
  },
  time: 10
)
