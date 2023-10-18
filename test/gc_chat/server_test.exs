defmodule GCChat.ServerTest do
  use GCChat.DataCase
  import GCChat.TestFixtures

  describe "handle_cast({:write, msgs}" do
    setup [:create_server]

    test "write 10k msgs with uniq channel", %{state: state} do
      {:noreply, %{buffers: buffers}} =
        GCChat.Server.handle_cast({:write, make_uniq_channel_msgs("uniq_10k", 10000)}, state)

      assert %CircularBuffer{count: 1} = cb = buffers["uniq_10k-1"]
      assert %GCChat.Message{id: 1} = CircularBuffer.oldest(cb)
      assert %GCChat.Message{id: 1} = CircularBuffer.newest(cb)
      assert cb == GCChat.LocalCache.get("uniq_10k-1")

      assert %CircularBuffer{count: 1} = cb = buffers["uniq_10k-10000"]
      assert %GCChat.Message{id: 1} = CircularBuffer.oldest(cb)
      assert %GCChat.Message{id: 1} = CircularBuffer.newest(cb)
      assert cb == GCChat.LocalCache.get("uniq_10k-10000")
    end

    test "write 10k msgs with same channel ", %{state: state} do
      num = 10000
      buffer_size = state.buffer_size

      {:noreply, %{buffers: buffers} = state} =
        GCChat.Server.handle_cast({:write, make_same_channel_msgs("same_10k", num)}, state)

      assert %CircularBuffer{count: ^buffer_size} = cb = buffers["same_10k"]

      oldest_id = num - buffer_size + 1
      assert %GCChat.Message{id: ^oldest_id} = CircularBuffer.oldest(cb)
      assert %GCChat.Message{id: ^num} = CircularBuffer.newest(cb)

      {:noreply, %{buffers: buffers}} =
        GCChat.Server.handle_cast({:write, make_same_channel_msgs("same_10k", num)}, state)

      assert %CircularBuffer{count: ^buffer_size} = cb = buffers["same_10k"]
      last_id = num * 2
      assert %GCChat.Message{id: ^last_id} = CircularBuffer.newest(cb)
      assert cb == GCChat.LocalCache.get("same_10k")
    end
  end
end
