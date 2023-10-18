defmodule GCChat.CacheAdapter.Local do
  use Nebulex.Cache, otp_app: :gc_chat, adapter: Nebulex.Adapters.Local

  @behaviour GCChat.CacheAdapter.Behaviour

  @impl true
  def update_caches(entries) do
    put_all(entries)
  end
end
