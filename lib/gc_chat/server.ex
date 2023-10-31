defmodule GCChat.Server do
  use GenServer
  @persist_interval 60
  defstruct entries: %{}, handler: nil, persist_interval: @persist_interval

  require Logger
  alias __MODULE__, as: M

  def send(worker, msgs) when is_list(msgs) do
    GenServer.cast(worker, {:receive_msgs, msgs})
  end

  def delete_entries(worker, entry_names) when is_list(entry_names) do
    GenServer.cast(worker, {:delete_entries, entry_names})
  end

  def fetch_entry(worker, entry_name) do
    try do
      GenServer.call(worker, {:fetch_entry, entry_name})
    catch
      :exit, reason ->
        Logger.error(gc_chat_server_error: reason)
        nil
    end
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
    persist_interval = Keyword.get(opts, :persist_interval, @persist_interval)
    id = Keyword.get(opts, :id)
    :yes = :global.re_register_name(worker_name(id), self())

    {:ok, %M{handler: handler, persist_interval: persist_interval}, {:continue, :initialize}}
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
  def handle_continue(:initialize, %M{persist_interval: persist_interval} = state) do
    loop()
    loop_persist(persist_interval)
    {:noreply, state}
  end

  defp loop() do
    Process.send_after(self(), :loop, @loop_interval)
  end

  defp loop_persist(persist_interval) do
    Process.send_after(self(), :loop_persist, persist_interval)
  end

  @impl true
  def handle_call({:fetch_entry, entry_name}, _from, %M{} = state) do
    {reply, state} = do_fetch_entry(state, entry_name)
    {:reply, reply, state}
  end

  defp do_fetch_entry(%M{entries: entries, handler: handler} = state, entry_name) do
    case entries[entry_name] do
      nil ->
        maybe_get_entry_from_db(handler, entry_name)
        |> case do
          nil ->
            {nil, state}

          %GCChat.Entry{} = entry ->
            entries = Map.put(entries, entry_name, entry)
            {entry, %M{state | entries: entries}}
        end

      entry ->
        {entry, state}
    end
  end

  def maybe_get_entry_from_db(handler, entry_name) do
    with {chat_type, _} <- GCChat.Entry.decode_name(entry_name),
         true <- GCChat.Config.enable_persist?(chat_type),
         {:ok, entry} <- handler.get_from_db(handler, entry_name) do
      entry
    else
      _ ->
        nil
    end
  end

  @impl true
  def handle_info(:loop, state) do
    state = maybe_drop_expired_entries(state)
    loop()
    {:noreply, state}
  end

  def handle_info(:loop_persist, %M{persist_interval: persist_interval} = state) do
    state = maybe_persist_entries(state)
    loop_persist(persist_interval)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:receive_msgs, msgs}, %M{} = state) do
    state = add_new_msgs(state, msgs)
    {:noreply, state}
  end

  def handle_cast({:delete_entries, entry_names}, %M{} = state) do
    state = do_drop_entries(state, entry_names)
    {:noreply, state}
  end

  def add_new_msgs(%M{entries: entries, handler: handler} = state, msgs) do
    changed_entries = calc_changed_entries(entries, msgs, handler.now())
    update_caches(handler, changed_entries)
    invalidate_all_node_fetch_entry_memo(handler, Map.keys(changed_entries))
    %M{state | entries: Map.merge(entries, changed_entries)}
  end

  defp calc_changed_entries(entries, msgs, now) do
    Enum.reduce(msgs, %{}, fn %GCChat.Message{chat_type: chat_type, channel: channel} = msg,
                              acc ->
      entry_name = GCChat.Entry.encode_name(chat_type, channel)

      (acc[entry_name] || get_or_create_entry(entries, entry_name, chat_type, now))
      |> GCChat.Entry.push(msg, now)
      |> then(&Map.put(acc, entry_name, &1))
    end)
  end

  defp get_or_create_entry(entries, entry_name, chat_type, now) do
    if entry = entries[entry_name] do
      entry
    else
      config = GCChat.Config.runtime_config(chat_type)
      GCChat.Entry.new(entry_name, now, config)
    end
  end

  defp update_caches(handler, changes) do
    handler.cache_adapter().update_caches(changes)
  end

  defp delete_caches(handler, keys) do
    handler.cache_adapter().delete_caches(keys)
  end

  defp invalidate_all_node_fetch_entry_memo(handler, keys) do
    handler.nodes()
    |> Enum.each(&:rpc.cast(&1, handler, :invalidate_fetch_entry_memo, [keys]))
  end

  def maybe_drop_expired_entries(%M{entries: entries, handler: handler} = state) do
    GCChat.Entry.find_expired_entry_names(entries, handler.now())
    |> then(&do_drop_entries(state, &1))
  end

  defp do_drop_entries(state, []) do
    state
  end

  defp do_drop_entries(%M{entries: entries, handler: handler} = state, entry_names) do
    entries = Map.drop(entries, entry_names)
    delete_caches(handler, entry_names)
    invalidate_all_node_fetch_entry_memo(handler, entry_names)
    %{state | entries: entries}
  end

  def maybe_persist_entries(%M{entries: entries} = state) do
    GCChat.Entry.find_persist_entry_names(entries)
    |> then(&do_persist_entries(state, &1))
  end

  defp do_persist_entries(%M{} = state, []) do
    state
  end

  defp do_persist_entries(%M{entries: entries, handler: handler} = state, entry_names) do
    now = handler.now()
    persist_entries = Map.take(entries, entry_names)
    handler.dump(persist_entries)

    entries =
      Enum.reduce(persist_entries, %{}, fn {k, v}, acc ->
        Map.put(acc, k, GCChat.Entry.update_persist_at(v, now))
      end)
      |> then(&Map.merge(entries, &1))

    %{state | entries: entries}
  end
end
