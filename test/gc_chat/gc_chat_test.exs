defmodule GCChat.GCChatTest do
  use GCChat.DataCase
  use ExUnit.Case, async: true
  import GCChat.TestFixtures

  describe "submit_msgs/2" do
    test "submit fail if all channel worker not exist" do
      entry_name = make_entry_name("#{System.unique_integer()}")
      [msg1, msg2, msg3, msg4] = make_uniq_channel_msgs(entry_name, 4)

      assert [msg1, msg2, msg3, msg4] ==
               GCChat.submit_msgs(%{:worker1 => [msg1, msg2], :worker2 => [msg3, msg4]}, 10)
    end
  end

  describe "BenchTest.Global.lookup/2" do
    test "return [1,2,3] if the remote node1,node2 and local node will send a msg by each node node1 and node2 " do
      entry_name = make_entry_name("#{System.unique_integer()}")

      [msg1, msg2, msg3] = make_same_channel_msgs(entry_name, 3)

      [n1, n2 | _] = Node.list()

      :rpc.block_call(n1, BenchTest.Global, :send, [msg1])
      Process.sleep(101)

      :rpc.block_call(n2, BenchTest.Global, :send, [msg2])
      Process.sleep(101)

      assert :ok == BenchTest.Global.send(msg3)
      Process.sleep(101)

      assert [{1, "body-1"}, {2, "body-2"}, {3, "body-3"}] ==
               BenchTest.Global.lookup(entry_name, 0) |> Enum.map(&{&1.id, &1.body})
    end
  end
end
