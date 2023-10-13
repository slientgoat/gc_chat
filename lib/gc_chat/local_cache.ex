defmodule GCChat.LocalCache do
  use Nebulex.Cache,
    otp_app: :gc_chat,
    adapter: Nebulex.Adapters.Local

  def lookup(channel, i) do
    GCChat.LocalCache.get(channel)
    |> find(i)
  end

  defp find(cb, i) do
    n = CircularBuffer.newest(cb)
    CircularBuffer.to_list(cb) |> Enum.take(i - n)
  end
end
