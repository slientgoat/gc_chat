defmodule GCChat do
  @moduledoc """
  Documentation for `GCChat`.
  """
  def send(attrs) do
    build(attrs)
    |> send_to()
  end

  def send_to({:ok, message}) do
    GCChat.Server.send(message)
  end

  def send_to(error) do
    error
  end

  def async_lookup(channel, from, i) do
    GCChat.Router.dispatch(channel, {:async_lookup, from, i})
  end

  defdelegate build(i), to: GCChat.Message
  defdelegate lookup(i), to: GCChat.Server

  def find(cb, i) do
    n = CircularBuffer.newest(cb)
    CircularBuffer.to_list(cb) |> Enum.take(i - n)
  end

  def create_buffer(x) do
    Enum.to_list(1..x)
    |> Enum.reduce(CircularBuffer.new(x), fn i, acc ->
      CircularBuffer.insert(acc, i)
    end)
  end
end
