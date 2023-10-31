defmodule GCChat.ServerTest do
  use GCChat.DataCase
  use ExUnit.Case, async: true
  import GCChat.TestFixtures
  alias GCChat.Entry

  describe "handle_cast({:receive_msgs, msgs}" do
    setup [:create_server]

    test "write 10k msgs with uniq channel", %{state: %GCChat.Server{handler: handler} = state} do
      entry_name = make_entry_name("uniq_10k")

      {:noreply, %GCChat.Server{entries: entries}} =
        GCChat.Server.handle_cast(
          {:receive_msgs, make_uniq_channel_msgs(entry_name, 10000)},
          state
        )

      first_entry_name = "#{entry_name}-1"

      assert %Entry{name: ^first_entry_name, cb: %CircularBuffer{count: 1} = cb, last_id: 1} =
               entry = entries[first_entry_name]

      assert %GCChat.Entry.Message{id: 1} = CircularBuffer.oldest(cb)
      assert %GCChat.Entry.Message{id: 1} = CircularBuffer.newest(cb)
      assert entry == cache_get(handler, first_entry_name)

      last_entry_name = "#{entry_name}-10000"

      assert %Entry{
               name: ^last_entry_name,
               cb: %CircularBuffer{count: 1} = cb2,
               last_id: 1
             } = entry2 = entries[last_entry_name]

      assert %GCChat.Entry.Message{id: 1} = CircularBuffer.oldest(cb2)
      assert %GCChat.Entry.Message{id: 1} = CircularBuffer.newest(cb2)
      assert entry2 == cache_get(handler, last_entry_name)
    end

    test "write 10k msgs with same channel ", %{state: %GCChat.Server{handler: handler} = state} do
      num = 10000
      buffer_size = GCChat.Config.default_buffer_size()
      ttl = GCChat.Config.default_ttl()
      entry_name = make_entry_name("same_10k")

      {:noreply, %GCChat.Server{entries: entries}} =
        GCChat.Server.handle_cast({:receive_msgs, make_same_channel_msgs(entry_name, num)}, state)

      assert %Entry{
               name: ^entry_name,
               last_id: 10000,
               ttl: ^ttl,
               cb: %CircularBuffer{count: ^buffer_size} = cb
             } = entry = entries[entry_name]

      oldest_id = num - buffer_size + 1
      assert %GCChat.Entry.Message{id: ^oldest_id} = CircularBuffer.oldest(cb)
      assert %GCChat.Entry.Message{id: ^num} = CircularBuffer.newest(cb)
      assert entry == cache_get(handler, entry_name)
    end
  end

  describe "handle_cast({:delete_entries, entries}" do
    setup [:create_server]

    test "delete_channel c1 after add c1", %{state: %GCChat.Server{handler: handler} = state} do
      entry_name = make_entry_name("#{System.unique_integer()}")
      state = add_channel_msgs(state, entry_name, 1)
      assert %Entry{cb: %CircularBuffer{count: 1}} = entry = state.entries[entry_name]
      assert entry == cache_get(handler, entry_name)

      {:noreply, state} = GCChat.Server.handle_cast({:delete_entries, [entry_name]}, state)

      assert nil == state.entries[entry_name]
    end
  end

  describe "fetch_entry/2" do
    test "return nil if worker process is not exist" do
      entry_name = make_entry_name("c1")
      assert nil == GCChat.Server.fetch_entry(:no_worker, entry_name)
    end

    test "return nil if worker process is exist but entry not exist" do
      entry_name = make_entry_name("c1")
      assert nil == GCChat.Server.fetch_entry(GCChat.Server.via_tuple(1), entry_name)
    end
  end

  # test "add_new_msgs/2", %{state: state} do
  #   add_msgs(state, {})
  # end

  defp cache_get(handler, key) do
    handler.cache_adapter().get(key)
  end

  # defp add_msgs(%GCChat.Server{} = state, channel, num \\ 1) do
  #   entry_name = GCChat.Entry.encode_name(0, channel)
  #   GCChat.Server.add_new_msgs(state, make_same_channel_msgs(entry_name, num))
  # end
end
