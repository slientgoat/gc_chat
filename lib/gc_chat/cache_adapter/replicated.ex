defmodule GCChat.CacheAdapter.Replicated do
  use Nebulex.Cache, otp_app: :gc_chat, adapter: Nebulex.Adapters.Replicated

  @behaviour GCChat.CacheAdapter.Behaviour

  @impl true
  def update_caches(entries) do
    put_all(entries)
  end

  def delete_caches(keys) do
    Enum.each(keys, &delete(&1))
  end
end
