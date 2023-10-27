defmodule GCChat.Server do
  use GenServer
  defstruct channels: %{}, handler: nil

  alias __MODULE__, as: M

  def send(worker, msgs) when is_list(msgs) do
    GenServer.cast(worker, {:receive_msgs, msgs})
  end

  def delete_channels(worker, channels) when is_list(channels) do
    GenServer.cast(worker, {:delete_channels, channels})
  end

  def child_spec(opts) do
    id = Keyword.get(opts, :id)

    %{
      id: "#{worker_name(id)}",
      start: {__MODULE__, :start_link, [opts]},
      shutdown: 10_000,
      restart: :transient
    }
  end

  def start_link(opts) do
    id = Keyword.get(opts, :id)
    GenServer.start_link(__MODULE__, opts, name: worker_name(id), hibernate_after: 100)
  end

  @impl true
  def init(opts) do
    handler = Keyword.get(opts, :instance)
    id = Keyword.get(opts, :id)
    :yes = :global.re_register_name(worker_name(id), self())

    {:ok, %M{handler: handler}, {:continue, :initialize}}
  end

  def pid(id) do
    via_tuple(id) |> GenServer.whereis()
  end

  def via_tuple(id) do
    {:global, worker_name(id)}
  end

  def worker_name(id), do: :"#{__MODULE__}.#{id}"

  @loop_interval 1000

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
  def handle_cast({:receive_msgs, msgs}, %M{channels: channels, handler: handler} = state) do
    changed_channels = handle_new_msgs(channels, Enum.reverse(msgs), handler.now())
    update_caches(handler, changed_channels)
    {:noreply, %M{state | channels: Map.merge(channels, changed_channels)}}
  end

  def handle_cast(
        {:delete_channels, channel_names},
        %M{channels: channels, handler: handler} = state
      ) do
    channels = Map.drop(channels, channel_names)
    delete_caches(handler, channel_names)
    {:noreply, %{state | channels: channels}}
  end

  def handle_new_msgs(channels, msgs, now) do
    Enum.reduce(msgs, %{}, fn %GCChat.Message{channel: channel} = msg, acc ->
      (acc[channel] || get_buffer(channels, msg, now))
      |> GCChat.Channel.push(msg, now)
      |> then(&Map.put(acc, channel, &1))
    end)
  end

  defp get_buffer(channels, %GCChat.Message{channel: channel, chat_type: chat_type}, now) do
    if buffer = channels[channel] do
      buffer
    else
      config = GCChat.Config.runtime_config(chat_type)
      GCChat.Channel.new(channel, now, config)
    end
  end

  defp update_caches(handler, changes) do
    handler.cache_adapter().update_caches(changes)
  end

  defp delete_caches(handler, keys) do
    handler.cache_adapter().delete_caches(keys)
  end
end
