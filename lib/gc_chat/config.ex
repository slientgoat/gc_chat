defmodule GCChat.Config do
  defstruct persist_interval: nil, ttl: 86400, buffer_size: 1000

  def default() do
    %__MODULE__{}
  end

  def runtime_config() do
    %{}
  end

  def runtime_config(chat_type) do
    runtime_config() |> Map.get(chat_type, default())
  end

  def enable_persist?(%__MODULE__{persist_interval: persist_interval}) do
    if persist_interval != nil and persist_interval >= 0 do
      true
    else
      false
    end
  end
end
