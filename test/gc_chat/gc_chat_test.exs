defmodule GCChat.GCChatTest do
  use GCChat.DataCase
  use ExUnit.Case, async: true
  import GCChat.TestFixtures

  describe "submit_msgs/3" do
    test "submit fail if all channel worker not exist" do
      entry_name = make_entry_name("#{System.unique_integer()}")

      buffers =
        make_uniq_channel_msgs(entry_name, 3)
        |> Enum.group_by(&GCChat.Server.to_entry_name/1)

      assert buffers == GCChat.submit_msgs(buffers, MyApp.Server, 10)
    end
  end

  describe "BenchTest.Global.lookup/2" do
    test "return [1,2,3] if the remote node1,node2 and local node will send a msg by each node node1 and node2 " do
      entry_name = make_entry_name("#{System.unique_integer()}")

      [msg1, msg2, msg3] = make_same_channel_msgs(entry_name, 3)

      [n1, n2 | _] = Node.list()

      assert :ok == :rpc.block_call(n1, MyApp.Client, :send, [msg1])
      Process.sleep(101)

      assert :ok == :rpc.block_call(n2, MyApp.Client, :send, [msg2])
      Process.sleep(101)

      assert :ok == MyApp.Client.send(msg3)
      Process.sleep(1000)

      IO.inspect(MyApp.Server.worker(1) |> GenServer.whereis(), label: "9999")

      assert [{1, "body-1"}, {2, "body-2"}, {3, "body-3"}] ==
               MyApp.Client.lookup(entry_name, 0) |> Enum.map(&{&1.id, &1.body})
    end
  end
end
