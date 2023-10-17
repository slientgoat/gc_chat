defmodule GCChat.Writter do
  use GenServer
  defstruct buffers: %{}

  @buffer_size 1000

  def buffer_size(), do: @buffer_size

  def write(msgs) when is_list(msgs) do
    write(pid(), msgs)
  end

  def pid() do
    via_tuple() |> GenServer.whereis()
  end

  def write(pid, msgs) when is_list(msgs) do
    GenServer.cast(pid, {:write, msgs})
  end

  def child_spec(opts) do
    name = Keyword.get(opts, :name, __MODULE__)

    %{
      id: "#{__MODULE__}_#{name}",
      start: {__MODULE__, :start_link, [name]},
      shutdown: 10_000,
      restart: :transient
    }
  end

  def start_link(name) do
    GenServer.start_link(__MODULE__, [], name: via_tuple(name), hibernate_after: 100)
  end

  @impl true
  def init(_args) do
    {:ok, %__MODULE__{}, {:continue, :initialize}}
  end

  def via_tuple(), do: via_tuple(__MODULE__)
  def via_tuple(name), do: {:via, Horde.Registry, {GCChat.GlobalRegistry, name}}

  @loop_interval 100

  @impl true
  def handle_continue(:initialize, state) do
    Process.send_after(self(), :loop, @loop_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info(:loop, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:write, msgs}, %{buffers: buffers} = state) do
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
