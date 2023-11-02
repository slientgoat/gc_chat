defmodule GCChat.Config do
  defstruct enable_persist: false, ttl: 86400, buffer_size: 1000

  def default() do
    %__MODULE__{}
  end

  def default_ttl(), do: %__MODULE__{}.ttl
  def default_buffer_size(), do: %__MODULE__{}.buffer_size

  def runtime_config() do
    %{}
  end

  def runtime_config(chat_type) do
    runtime_config() |> Map.get(chat_type, default())
  end

  def enable_persist?(chat_type) when is_integer(chat_type) do
    enable_persist?(runtime_config(chat_type))
  end

  def enable_persist?(%__MODULE__{enable_persist: enable_persist}) do
    if enable_persist == true do
      true
    else
      false
    end
  end
end
