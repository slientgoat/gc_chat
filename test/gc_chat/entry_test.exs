defmodule GCChat.EntryTest do
  use GCChat.DataCase
  use ExUnit.Case, async: true

  alias GCChat.Entry

  describe "new/2" do
    test "with default config" do
      now = System.os_time(:second)
      entry = Entry.new("test1", now, GCChat.Config.default())
      default_ttl = GCChat.Config.default_ttl()
      default_buffer_size = GCChat.Config.default_buffer_size()

      assert %Entry{
               name: "test1",
               cb: cb,
               ttl: ^default_ttl,
               touched_at: ^now,
               updated_at: ^now,
               created_at: ^now,
               enable_persist: false
             } = entry

      assert %CircularBuffer{max_size: ^default_buffer_size, count: 0} = cb
    end

    test "with a persist_at attr" do
      now = System.os_time(:second)
      config = GCChat.Config.default() |> Map.put(:persist_interval, :timer.seconds(1))
      entry = Entry.new("test1", now, config)

      assert true == Entry.persist?(entry)
    end
  end

  test "a expired entry because of touched_at" do
    now = System.os_time(:second)

    entry =
      Entry.new("test1", now, GCChat.Config.default())
      |> Entry.update_touched_at(now - GCChat.Config.default_ttl())

    assert true == Entry.expired?(entry, now)
  end

  test "a expired entry because of updated_at" do
    now = System.os_time(:second)

    entry =
      Entry.new("test1", now, GCChat.Config.default())
      |> Entry.update_updated_at(now - GCChat.Config.default_ttl() - 86400)

    assert true == Entry.expired?(entry, now)
  end
end
