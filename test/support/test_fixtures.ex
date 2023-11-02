defmodule GCChat.TestFixtures do
  def make_uniq_channel_msgs(entry_name, num) do
    {chat_type, channel} = GCChat.Entry.decode_name(entry_name)

    fn x -> "#{channel}-#{x}" end
    |> make_channel_msgs(num, chat_type)
  end

  def make_same_channel_msgs(entry_name, num) do
    {chat_type, channel} = GCChat.Entry.decode_name(entry_name)

    fn _x -> channel end
    |> make_channel_msgs(num, chat_type)
  end

  defp make_channel_msgs(channel_cast_fun, num, chat_type) do
    for i <- Enum.to_list(1..num) do
      {:ok, msg} =
        GCChat.Message.build(%{
          chat_type: chat_type,
          body: "body-#{i}",
          channel: channel_cast_fun.(i),
          from: i,
          send_at: 1
        })

      msg
    end
  end

  def create_server(_args \\ []) do
    state = MyApp.Server.handle_init(%{id: 1}) |> MyApp.Server.handle_continue()
    %{state: state}
  end

  def wait_for_server_started(f_pid) do
    if f_pid.() |> is_pid() do
      :ok
    else
      Process.sleep(100)
      wait_for_server_started(f_pid)
    end
  end

  def make_entry_name(channel, chat_type \\ 0) do
    GCChat.Entry.encode_name(chat_type, channel)
  end
end
