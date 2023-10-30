defmodule GCChat.CacheAdapter.Behaviour do
  @callback update_caches(GCChat.Entry.entries()) :: :ok
end
