defmodule GCChat.Entry do
  @type t :: CircularBuffer.t()
  @type entries :: %{GCChat.Message.channel() => t()}

  def take(cb, last_id) when not is_nil(cb) and is_integer(last_id) and last_id >= 0 do
    n = CircularBuffer.newest(cb)
    CircularBuffer.to_list(cb) |> Enum.take(last_id - n.id)
  end

  def get_last_id(cb) do
    CircularBuffer.newest(cb)
    |> case do
      %GCChat.Message{id: id} ->
        id

      nil ->
        0
    end
  end

  def insert(cb, %GCChat.Message{} = msg) do
    CircularBuffer.insert(cb, msg)
  end

  def new(size) do
    CircularBuffer.new(size)
  end
end
