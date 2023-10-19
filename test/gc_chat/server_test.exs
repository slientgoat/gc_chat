defmodule GCChat.ServerTest do
  use GCChat.DataCase
  import GCChat.TestFixtures

  describe "handle_cast({:receive_msgs, msgs}" do
    setup [:create_server]

    test "write 10k msgs with uniq channel", %{state: %GCChat.Server{cache: cache} = state} do
      {:noreply, %{buffers: buffers}} =
        GCChat.Server.handle_cast(
          {:receive_msgs, make_uniq_channel_msgs("uniq_10k", 10000)},
          state
        )

      assert %CircularBuffer{count: 1} = cb = buffers["uniq_10k-1"]
      assert %GCChat.Message{id: 1} = CircularBuffer.oldest(cb)
      assert %GCChat.Message{id: 1} = CircularBuffer.newest(cb)
      assert cb == cache.get("uniq_10k-1")

      assert %CircularBuffer{count: 1} = cb = buffers["uniq_10k-10000"]
      assert %GCChat.Message{id: 1} = CircularBuffer.oldest(cb)
      assert %GCChat.Message{id: 1} = CircularBuffer.newest(cb)
      assert cb == cache.get("uniq_10k-10000")
    end

    test "write 10k msgs with same channel ", %{state: %GCChat.Server{cache: cache} = state} do
      num = 10000
      buffer_size = state.buffer_size

      {:noreply, %{buffers: buffers} = state} =
        GCChat.Server.handle_cast({:receive_msgs, make_same_channel_msgs("same_10k", num)}, state)

      assert %CircularBuffer{count: ^buffer_size} = cb = buffers["same_10k"]

      oldest_id = num - buffer_size + 1
      assert %GCChat.Message{id: ^oldest_id} = CircularBuffer.oldest(cb)
      assert %GCChat.Message{id: ^num} = CircularBuffer.newest(cb)

      {:noreply, %{buffers: buffers}} =
        GCChat.Server.handle_cast({:receive_msgs, make_same_channel_msgs("same_10k", num)}, state)

      assert %CircularBuffer{count: ^buffer_size} = cb = buffers["same_10k"]
      last_id = num * 2
      assert %GCChat.Message{id: ^last_id} = CircularBuffer.newest(cb)
      assert cb == cache.get("same_10k")
    end
  end

  describe "handle_cast({:delete_channel, channels}" do
    setup [:create_server]

    test "delete_channel c1 after add c1", %{state: %GCChat.Server{cache: cache} = state} do
      c = "#{System.unique_integer()}"

      state = add_channel_msgs(state, c, 1)
      assert %CircularBuffer{count: 1} = cb = state.buffers[c]
      assert cb == cache.get(c)

      {:noreply, state} = GCChat.Server.handle_cast({:delete_channels, [c]}, state)

      assert nil == state.buffers[c]
    end
  end

  describe "BenchTest.Global.lookup(1,0) " do
    test "return [2,1] if send 2 msg" do
      c = "#{System.unique_integer()}"
      assert [] = BenchTest.Global.lookup(c, 0) |> Enum.map(& &1.id)
      GCChat.Message.build(%{body: "body1", channel: c, from: 1}) |> BenchTest.Global.send()
      GCChat.Message.build(%{body: "body2", channel: c, from: 1}) |> BenchTest.Global.send()
      Process.sleep(100)

      assert [{1, "body1"}, {2, "body2"}] =
               BenchTest.Global.lookup(c, 0) |> Enum.map(&{&1.id, &1.body})
    end
  end

  describe "BenchTest.Global.lookup(2,0) at gc-chat-cluster-2@127.0.0.1" do
    test "return [2,1] if send 2 msg" do
      c = "#{System.unique_integer()}"
      :ok = LocalCluster.start()
      [n1, n2 | _] = LocalCluster.start_nodes("gc-chat-cluster", 2)

      :rpc.block_call(n1, BenchTest.Global, :send, [
        GCChat.Message.build(%{body: "body1", channel: c, from: 1})
      ])

      :rpc.block_call(n2, BenchTest.Global, :send, [
        GCChat.Message.build(%{body: "body2", channel: c, from: 1})
      ])

      Process.sleep(101)
      assert [1, 2] == BenchTest.Global.lookup(c, 0) |> Enum.map(& &1.id)
    end
  end
end
