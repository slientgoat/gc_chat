defmodule GCChat.Server do
  use GenServer
  defstruct buffers: %{}, persist: nil, persist_interval: nil, cache: nil, buffer_size: nil

  alias __MODULE__, as: M
  alias GCChat.Entry

  def send(chat_type, msgs) when is_list(msgs) do
    GenServer.cast(pid(chat_type), {:receive_msgs, msgs})
  end

  def delete_channels(chat_type, channel) do
    GenServer.cast(pid(chat_type), {:delete_channels, channel})
  end

  def pid(chat_type) do
    via_tuple(chat_type) |> GenServer.whereis()
  end

  def child_spec(opts) do
    chat_type = Keyword.get(opts, :chat_type)

    %{
      id: "#{chat_type}.Server",
      start: {__MODULE__, :start_link, [opts]},
      shutdown: 10_000,
      restart: :transient
    }
  end

  def start_link(opts) do
    chat_type = Keyword.get(opts, :chat_type)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(chat_type), hibernate_after: 100)
  end

  @impl true
  def init(opts) do
    persist = Keyword.get(opts, :persist)
    persist_interval = Keyword.get(opts, :persist_interval)
    chat_type = Keyword.get(opts, :chat_type)
    cache = chat_type.cache_adapter()
    buffer_size = Keyword.get(opts, :buffer_size, 1000)

    {:ok,
     %M{
       persist: persist,
       persist_interval: persist_interval,
       cache: cache,
       buffer_size: buffer_size
     }, {:continue, :initialize}}
  end

  def via_tuple(chat_type),
    do: {:via, Horde.Registry, {GCChat.GlobalRegistry, :"#{chat_type}.Server"}}

  @impl true
  def handle_continue(:initialize, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:loop, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:receive_msgs, msgs},
        %M{buffers: buffers, buffer_size: buffer_size, cache: cache} = state
      ) do
    {buffers, changed_keys} = write_msgs(buffers, msgs, buffer_size)
    update_caches(cache, Map.take(buffers, changed_keys))
    {:noreply, %{state | buffers: buffers}}
  end

  def handle_cast({:delete_channels, channels}, %M{buffers: buffers, cache: cache} = state) do
    buffers = Map.drop(buffers, channels)
    delete_caches(cache, channels)
    {:noreply, %{state | buffers: buffers}}
  end

  def write_msgs(buffers, msgs, buffer_size) do
    group_by_channel(msgs)
    |> Enum.reduce({buffers, []}, fn {channel, channel_msgs}, {acc, keys} ->
      (buffers[channel] || Entry.new(buffer_size))
      |> update_channel_msgs(channel_msgs)
      |> then(&{Map.put(acc, channel, &1), [channel | keys]})
    end)
  end

  defp group_by_channel(msgs) do
    Enum.group_by(msgs, & &1.channel)
  end

  defp update_channel_msgs(cb, channel_msgs) do
    last_id = Entry.get_last_id(cb)

    channel_msgs
    |> Enum.reduce({cb, last_id}, fn msg, {acc, id} ->
      id = id + 1
      {Entry.insert(acc, %{msg | id: id}), id}
    end)
    |> elem(0)
  end

  defp update_caches(cache, changes) do
    cache.update_caches(changes)
  end

  defp delete_caches(cache, channels) do
    cache.delete_caches(channels)
  end
end
