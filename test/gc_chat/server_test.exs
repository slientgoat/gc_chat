defmodule GCChat.ServerTest do
  use GCChat.DataCase
  use ExUnit.Case, async: true
  import GCChat.TestFixtures
  alias GCChat.Entry

  describe "handle_cast({:receive_msgs, msgs}" do
    setup [:create_server]

    test "write 10k msgs with uniq channel", %{state: %GCChat.Server{handler: handler} = state} do
      {:noreply, %GCChat.Server{entries: entries}} =
        GCChat.Server.handle_cast(
          {:receive_msgs, make_uniq_channel_msgs("uniq_10k", 10000)},
          state
        )

      assert %Entry{name: "uniq_10k-1", cb: %CircularBuffer{count: 1} = cb, last_id: 1} =
               entry = entries["uniq_10k-1"]

      assert %GCChat.Entry.Message{id: 1} = CircularBuffer.oldest(cb)
      assert %GCChat.Entry.Message{id: 1} = CircularBuffer.newest(cb)
      assert entry == cache_get(handler, "uniq_10k-1")

      assert %Entry{
               name: "uniq_10k-10000",
               cb: %CircularBuffer{count: 1} = cb2,
               last_id: 1
             } = entry2 = entries["uniq_10k-10000"]

      assert %GCChat.Entry.Message{id: 1} = CircularBuffer.oldest(cb2)
      assert %GCChat.Entry.Message{id: 1} = CircularBuffer.newest(cb2)
      assert entry2 == cache_get(handler, "uniq_10k-10000")
    end

    test "write 10k msgs with same channel ", %{state: %GCChat.Server{handler: handler} = state} do
      num = 10000
      buffer_size = GCChat.Config.default_buffer_size()
      ttl = GCChat.Config.default_ttl()

      {:noreply, %GCChat.Server{entries: entries}} =
        GCChat.Server.handle_cast({:receive_msgs, make_same_channel_msgs("same_10k", num)}, state)

      assert %Entry{
               name: "same_10k",
               last_id: 10000,
               ttl: ^ttl,
               cb: %CircularBuffer{count: ^buffer_size} = cb
             } = entry = entries["same_10k"]

      oldest_id = num - buffer_size + 1
      assert %GCChat.Entry.Message{id: ^oldest_id} = CircularBuffer.oldest(cb)
      assert %GCChat.Entry.Message{id: ^num} = CircularBuffer.newest(cb)
      assert entry == cache_get(handler, "same_10k")
    end
  end

  describe "handle_cast({:delete_entries, entries}" do
    setup [:create_server]

    test "delete_channel c1 after add c1", %{state: %GCChat.Server{handler: handler} = state} do
      c = "#{System.unique_integer()}"

      state = add_channel_msgs(state, c, 1)
      assert %Entry{cb: %CircularBuffer{count: 1}} = entry = state.entries[c]
      assert entry == cache_get(handler, c)

      {:noreply, state} = GCChat.Server.handle_cast({:delete_entries, [c]}, state)

      assert nil == state.entries[c]
    end
  end

  describe "BenchTest.Global.lookup/2" do
    test "return [1,2,3] if the remote node1,node2 and local node will send a msg by each node node1 and node2 " do
      c = "#{System.unique_integer()}"
      [n1, n2 | _] = Node.list()

      :rpc.block_call(n1, BenchTest.Global, :send, [
        GCChat.Message.build(%{chat_type: 0, body: "body1", channel: c, from: 1})
      ])

      :rpc.block_call(n2, BenchTest.Global, :send, [
        GCChat.Message.build(%{chat_type: 0, body: "body2", channel: c, from: 1})
      ])

      Process.sleep(101)

      assert :ok ==
               GCChat.Message.build(%{chat_type: 0, body: "body3", channel: c, from: 1})
               |> BenchTest.Global.send()

      Process.sleep(101)

      assert [{1, "body1"}, {2, "body2"}, {3, "body3"}] ==
               BenchTest.Global.lookup(c, 0) |> Enum.map(&{&1.id, &1.body})
    end
  end

  defp cache_get(handler, key) do
    handler.cache_adapter().get(key)
  end
end
