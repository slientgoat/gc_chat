defmodule GCChat.TestFixtures do
  def make_uniq_channel_msgs(channel_prfix, num) do
    fn x -> "#{channel_prfix}-#{x}" end
    |> make_channel_msgs(num)
  end

  def make_same_channel_msgs(channel, num) do
    fn _x -> channel end
    |> make_channel_msgs(num)
  end

  defp make_channel_msgs(channel_cast_fun, num) do
    for i <- Enum.to_list(1..num) do
      {:ok, msg} =
        GCChat.Message.build(%{
          body: "body-#{i}",
          channel: channel_cast_fun.(i),
          from: i,
          send_at: 1
        })

      msg
    end
  end

  def create_writter(_args \\ []) do
    opts = [id: 1, handler: SimpleHandler]
    {:ok, state, {:continue, continue}} = GCChat.Writter.init([])
    {:noreply, state} = GCChat.Writter.handle_continue(continue, state)
    %{state: state}
  end
end
