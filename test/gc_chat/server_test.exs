defmodule GCChat.ServerTest do
  use GCChat.DataCase
  use ExUnit.Case, async: true
  import GCChat.TestFixtures
  alias GCChat.Entry

  setup_all _ do
    create_server()
  end

  describe "do_add_new_msgs/2" do
    test "write 10k msgs with uniq channel", %{state: %GCChat.Server{} = state} do
      entry_name = make_entry_name("uniq_10k")

      %GCChat.Server{entries: entries} =
        state = add_uniq_channel_msgs(state, entry_name, 10000)

      first_entry_name = "#{entry_name}-1"

      assert %Entry{name: ^first_entry_name, cb: %CircularBuffer{count: 1} = cb, last_id: 1} =
               entry = entries[first_entry_name]

      assert %GCChat.Entry.Message{id: 1} = CircularBuffer.oldest(cb)
      assert %GCChat.Entry.Message{id: 1} = CircularBuffer.newest(cb)
      assert entry == direct_get(state, first_entry_name)

      last_entry_name = "#{entry_name}-10000"

      assert %Entry{
               name: ^last_entry_name,
               cb: %CircularBuffer{count: 1} = cb2,
               last_id: 1
             } = direct_get(state, last_entry_name)

      assert %GCChat.Entry.Message{id: 1} = CircularBuffer.oldest(cb2)
      assert %GCChat.Entry.Message{id: 1} = CircularBuffer.newest(cb2)
    end

    test "write 10k msgs with same channel ", %{state: %GCChat.Server{} = state} do
      num = 10000
      buffer_size = GCChat.Config.default_buffer_size()
      ttl = GCChat.Config.default_ttl()
      entry_name = make_entry_name("same_10k")

      state = add_same_channel_msgs(state, entry_name, num)

      assert %Entry{
               name: ^entry_name,
               last_id: 10000,
               ttl: ^ttl,
               cb: %CircularBuffer{count: ^buffer_size} = cb
             } = direct_get(state, entry_name)

      oldest_id = num - buffer_size + 1
      assert %GCChat.Entry.Message{id: ^oldest_id} = CircularBuffer.oldest(cb)
      assert %GCChat.Entry.Message{id: ^num} = CircularBuffer.newest(cb)
    end
  end

  describe "do_delete_entries/2" do
    setup [:create_server]

    test "delete_channel c1 after add c1", %{state: %GCChat.Server{} = state} do
      entry_name = make_entry_name("#{System.unique_integer()}")
      state = add_same_channel_msgs(state, entry_name, 1)
      assert %Entry{cb: %CircularBuffer{count: 1}} = entry = state.entries[entry_name]
      assert entry == direct_get(state, entry_name)
      state = GCChat.Server.do_delete_entries(state, [entry_name])
      assert nil == state.entries[entry_name]
    end
  end

  # describe "fetch_entry/2" do
  #   test "return nil if worker process is not exist", %{state: %GCChat.Server{} = state} do
  #     entry_name = make_entry_name("c1")
  #     assert nil == GCChat.Server.do_fetch_entry(state, entry_name)
  #   end

  #   test "return nil if worker process is exist but entry not exist" do
  #     entry_name = make_entry_name("c1")
  #     assert nil == GCChat.Server.fetch_entry(GCChat.Server.via_tuple(1), entry_name)
  #   end
  # end

  describe "do_fetch_entry/2" do
    test "return nil if the entry is not exist", %{state: %GCChat.Server{} = state} do
      entry_name = make_entry_name("c1")
      assert {nil, state} == GCChat.Server.do_fetch_entry(state, entry_name)
    end

    test "return Entry if the entry is exist ", %{state: %GCChat.Server{} = state} do
      entry_name = make_entry_name("c1")
      state = add_same_channel_msgs(state, entry_name, 1)
      assert {%GCChat.Entry{}, ^state} = GCChat.Server.do_fetch_entry(state, entry_name)
    end
  end

  defp direct_get(state, entry_name) do
    {reply, _state} = GCChat.Server.do_fetch_entry(state, entry_name)
    reply
  end

  defp add_uniq_channel_msgs(state, entry_name, num) do
    GCChat.Server.do_add_new_msgs(state, make_uniq_channel_msgs(entry_name, num))
  end

  defp add_same_channel_msgs(state, entry_name, num) do
    GCChat.Server.do_add_new_msgs(state, make_same_channel_msgs(entry_name, num))
  end

  # defp add_msgs(%GCChat.Server{} = state, channel, num \\ 1) do
  #   entry_name = GCChat.Entry.encode_name(0, channel)
  #   GCChat.Server.add_new_msgs(state, make_same_channel_msgs(entry_name, num))
  # end
end
