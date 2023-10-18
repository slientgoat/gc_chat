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

  def create_server(_args \\ []) do
    {:ok, state, {:continue, continue}} = GCChat.Server.init([])
    {:noreply, state} = GCChat.Server.handle_continue(continue, state)
    %{state: state}
  end

  def wait_for_server_started(chat_type) do
    if chat_type.server() |> is_pid() do
      :ok
    else
      Process.sleep(100)
      wait_for_server_started(chat_type)
    end
  end
end