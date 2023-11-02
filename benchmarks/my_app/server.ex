defmodule MyApp.Server do
  use EasyHorde, worker_num: 128, registry_name: Matrix.GlobalRegistry
  use GCChat.Server, persist_interval: 60

  def chat_type_config() do
    %{
      88 => [ttl: 1],
      99 => [enable_persist: true]
    }
  end
end
