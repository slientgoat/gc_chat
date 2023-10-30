defmodule GCChat.Server do
  use GenServer
  defstruct entries: %{}, handler: nil

  alias __MODULE__, as: M

  def send(worker, msgs) when is_list(msgs) do
    GenServer.cast(worker, {:receive_msgs, msgs})
  end

  def delete_entries(worker, entries) when is_list(entries) do
    GenServer.cast(worker, {:delete_entries, entries})
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
  def handle_cast({:receive_msgs, msgs}, %M{entries: entries, handler: handler} = state) do
    changed_entries = handle_new_msgs(entries, msgs, handler.now())
    update_caches(handler, changed_entries)
    {:noreply, %M{state | entries: Map.merge(entries, changed_entries)}}
  end

  def handle_cast(
        {:delete_entries, channel_names},
        %M{entries: entries, handler: handler} = state
      ) do
    entries = Map.drop(entries, channel_names)
    delete_caches(handler, channel_names)
    {:noreply, %{state | entries: entries}}
  end

  def handle_new_msgs(entries, msgs, now) do
    Enum.reduce(msgs, %{}, fn %GCChat.Message{channel: channel} = msg, acc ->
      (acc[channel] || get_buffer(entries, msg, now))
      |> GCChat.Entry.push(msg, now)
      |> then(&Map.put(acc, channel, &1))
    end)
  end

  defp get_buffer(entries, %GCChat.Message{channel: channel, chat_type: chat_type}, now) do
    if buffer = entries[channel] do
      buffer
    else
      config = GCChat.Config.runtime_config(chat_type)
      GCChat.Entry.new(channel, now, config)
    end
  end

  defp update_caches(handler, changes) do
    handler.cache_adapter().update_caches(changes)
  end

  defp delete_caches(handler, keys) do
    handler.cache_adapter().delete_caches(keys)
  end
end
