defmodule GCChat.Server do
  use GenServer
  defstruct buffers: %{}, persist: nil, persist_interval: nil, handler: nil
  import ShorterMaps

  alias GCChat.Server, as: M
  @buffer_size 1000

  def buffer_size(), do: @buffer_size

  def send(chat_type, msgs) when is_list(msgs) do
    write(pid(chat_type), msgs)
  end

  def pid(chat_type) do
    via_tuple(chat_type) |> GenServer.whereis()
  end

  defp write(pid, msgs) when is_list(msgs) do
    GenServer.cast(pid, {:write, msgs})
  end

  def child_spec(opts) do
    chat_type = Keyword.get(opts, :chat_type, __MODULE__)

    %{
      id: "#{chat_type}.Server",
      start: {__MODULE__, :start_link, [opts]},
      shutdown: 10_000,
      restart: :transient
    }
  end

  def start_link(opts) do
    chat_type = Keyword.get(opts, :chat_type, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(chat_type), hibernate_after: 100)
  end

  @impl true
  def init(opts) do
    persist = Keyword.get(opts, :persist)
    persist_interval = Keyword.get(opts, :persist_interval)
    handler = Keyword.get(opts, :chat_type, __MODULE__)
    {:ok, ~M{%M persist,persist_interval,handler}, {:continue, :initialize}}
  end

  def via_tuple(chat_type),
    do: {:via, Horde.Registry, {GCChat.GlobalRegistry, :"#{chat_type}.Server"}}

  @loop_interval 100

  @impl true
  def handle_continue(:initialize, state) do
    Process.send_after(self(), :loop, @loop_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info(:loop, state) do
    Process.send_after(self(), :loop, @loop_interval)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:write, msgs}, %M{buffers: buffers} = state) do
    buffers = write_msgs(buffers, msgs)
    {:noreply, %{state | buffers: buffers}}
  end

  def write_msgs(buffers, msgs) do
    msgs
    |> group_by_channel()
    |> update_channels(buffers)
  end

  defp update_channels(channel_msgs, buffers) do
    for {channel, msgs} <- channel_msgs, into: %{} do
      (buffers[channel] || CircularBuffer.new(@buffer_size))
      |> update_channel_msgs(msgs)
      |> then(&{channel, &1})
    end
    |> then(&Map.merge(buffers, &1))
  end

  def write_msgs(msgs) do
    msgs
    |> group_by_channel()
    |> update_channels()
  end

  defp group_by_channel(msgs) do
    Enum.group_by(msgs, & &1.channel)
  end

  defp update_channels(channel_msgs) do
    for {channel, msgs} <- channel_msgs do
      get_cb(channel)
      |> update_channel_msgs(msgs)
      |> update_cb(channel)
    end
  end

  defp get_cb(channel) do
    :ets.lookup(__MODULE__, channel)
    |> case do
      [{_, v}] ->
        v

      _ ->
        CircularBuffer.new(@buffer_size)
    end
  end

  defp update_channel_msgs(cb, msgs) do
    last_id = get_last_id(cb)

    msgs
    |> Enum.reduce({cb, last_id}, fn msg, {acc, id} ->
      id = id + 1
      {CircularBuffer.insert(acc, %{msg | id: id}), id}
    end)
    |> elem(0)
  end

  defp update_cb(cb, channel) do
    :ets.insert(__MODULE__, {channel, cb})
  end

  defp get_last_id(cb) do
    CircularBuffer.newest(cb)
    |> case do
      %GCChat.Message{id: id} ->
        id

      nil ->
        0
    end
  end
end
