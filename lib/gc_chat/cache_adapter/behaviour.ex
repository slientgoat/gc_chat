defmodule GCChat.CacheAdapter.Behaviour do
  @callback update_caches(GCChat.Channel.entries()) :: :ok
end
