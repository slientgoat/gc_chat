defmodule BenchTest.Global do
  use GCChat, cache_adapter: GCChat.CacheAdapter.Replicated

  def chat_type_config() do
    %{
      88 => [ttl: 1],
      99 => [persist_interval: 1000]
    }
  end
end
