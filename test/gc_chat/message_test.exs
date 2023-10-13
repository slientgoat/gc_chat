defmodule GCChat.MessageTest do
  use GCChat.DataCase
  alias GCChat.Message

  test "validate_body for length over limit " do
    maximum = Message.max_body_length()
    temp = List.duplicate("a", maximum * 2) |> Enum.join("")

    {:error, changeset} = Message.validate(&Message.validate_body/1, %{body: temp})
    expert_tips = "should be at most #{maximum} character(s)"
    assert %{body: [expert_tips]} == errors_on(changeset)
  end

  describe "build/1" do
    test "require body,channel,from" do
      {:error, changeset} = GCChat.Message.build(%{})

      assert %{body: ["can't be blank"], channel: ["can't be blank"], from: ["can't be blank"]} ==
               errors_on(changeset)
    end

    test "return {:ok,%Message{}} when all normal" do
      assert {:ok, %Message{send_at: send_at}} =
               GCChat.Message.build(%{body: "body", channel: "1", from: 1})

      assert true == send_at > 0
    end

    test "return {:ok,%Message{send_at: 1}} by pass send_at=1" do
      assert {:ok, %Message{send_at: 1}} =
               GCChat.Message.build(%{body: "body", channel: "1", from: 1, send_at: 1})
    end
  end
end
