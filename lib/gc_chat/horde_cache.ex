defmodule GCChat.HordeCache do
  use Nebulex.Cache,
    otp_app: :nebulex_adapters_horde,
    adapter: Nebulex.Adapters.Horde

  def lookup(channel, i) do
    GCChat.HordeCache.get(channel)
    |> find(i)
  end

  defp find(cb, i) do
    n = CircularBuffer.newest(cb)
    CircularBuffer.to_list(cb) |> Enum.take(i - n)
  end
end
