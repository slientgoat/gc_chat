defmodule GCChat.EntryTest do
  use GCChat.DataCase
  use ExUnit.Case, async: true

  # describe "new/2" do
  #   test "submit fail if all channel worker not exist" do
  #     [msg1, msg2, msg3, msg4] = make_uniq_channel_msgs("GCChatTest", 4)

  #     assert [msg1, msg2, msg3, msg4] ==
  #              GCChat.submit_msgs(%{:worker1 => [msg1, msg2], :worker2 => [msg3, msg4]}, 10)
  #   end
  # end
end
