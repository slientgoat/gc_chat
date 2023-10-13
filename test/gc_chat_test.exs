defmodule GCChatTest do
  use ExUnit.Case
  doctest GCChat

  describe "send/1" do
    test "return error if attrs is not valid" do
      assert {:error, _} = GCChat.send(%{})
    end

    test "return ok if attrs is  valid" do
      assert :ok = GCChat.send(%{channel: "1", from: 1, body: "2"})
    end
  end
end
