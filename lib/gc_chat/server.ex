defmodule GCChat.Server do
  defstruct id: nil, entries: %{}, handler: nil
  alias __MODULE__, as: M
  require Logger

  @opts_schema [
    persist_interval: [
      type: :non_neg_integer,
      doc: "persist entries for every [persist_interval] seconds",
      default: 60
    ]
  ]

  def parse_opts(opts) do
    {:ok, default} = NimbleOptions.validate(opts, @opts_schema)
    default
  end

  def send(server, key, msgs) when is_list(msgs) do
    server.worker(key)
    |> cast(&do_add_new_msgs/2, msgs)
  end

  def fetch_entry(server, entry_name) do
    server.worker(entry_name)
    |> rpc(&do_fetch_entry/2, entry_name)
  end

  def rpc(worker, fun, fun_args) do
    try do
      IO.inspect(fun)
      GenServer.call(worker, {:rpc, fun, fun_args})
    catch
      :exit, reason ->
        Logger.error(gc_chat_server_error: reason)
        nil
    end
  end

  def cast(worker, fun, fun_args) do
    try do
      GenServer.cast(worker, {:cast, fun, fun_args})
      :ok
    catch
      :exit, reason ->
        Logger.error(gc_chat_server_error: reason)
        :error
    end
  end

  def do_fetch_entry(%M{entries: entries, handler: handler} = state, entry_name) do
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
         {:ok, entry} <- handler.get_from_db(entry_name) do
      entry
    else
      _ ->
        nil
    end
  end

  def do_add_new_msgs(%M{entries: entries, handler: handler} = state, msgs) do
    IO.inspect(msgs, label: :do_add_new_msgs)
    changed_entries = calc_changed_entries(entries, msgs, handler.now())
    invalidate_all_node_fetch_entry_memo(handler, Map.keys(changed_entries))
    %M{state | entries: Map.merge(entries, changed_entries)}
  end

  defp calc_changed_entries(entries, msgs, now) do
    Enum.reduce(msgs, %{}, fn %GCChat.Message{chat_type: chat_type} = msg, acc ->
      entry_name = to_entry_name(msg)

      (acc[entry_name] || get_or_create_entry(entries, entry_name, chat_type, now))
      |> GCChat.Entry.push(msg, now)
      |> then(&Map.put(acc, entry_name, &1))
    end)
  end

  def to_entry_name(%GCChat.Message{channel: channel, chat_type: chat_type}) do
    GCChat.Entry.encode_name(chat_type, channel)
  end

  defp get_or_create_entry(entries, entry_name, chat_type, now) do
    if entry = entries[entry_name] do
      entry
    else
      config = GCChat.Config.runtime_config(chat_type)
      GCChat.Entry.new(entry_name, now, config)
    end
  end

  def maybe_drop_expired_entries(%M{entries: entries, handler: handler} = state) do
    GCChat.Entry.find_expired_entry_names(entries, handler.now())
    |> then(&do_delete_entries(state, &1))
  end

  def do_delete_entries(state, []) do
    state
  end

  def do_delete_entries(%M{entries: entries, handler: handler} = state, entry_names) do
    entries = Map.drop(entries, entry_names)
    invalidate_all_node_fetch_entry_memo(handler, entry_names)
    %{state | entries: entries}
  end

  defp invalidate_all_node_fetch_entry_memo(handler, keys) do
    get_client_nodes(handler)
    |> Enum.each(&:rpc.cast(&1, handler, :invalidate_fetch_entry_memo, [keys]))
  end

  def maybe_persist_entries(%M{entries: entries} = state) do
    GCChat.Entry.find_persist_entry_names(entries)
    |> then(&do_persist_entries(state, &1))
  end

  defp do_persist_entries(%M{} = state, []) do
    state
  end

  defp do_persist_entries(%M{id: id, entries: entries, handler: handler} = state, entry_names) do
    now = handler.now()

    persist_entries =
      Map.take(entries, entry_names)
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        Map.put(acc, k, GCChat.Entry.update_persist_at(v, now))
      end)

    exec_callback(handler, :dump, [id, persist_entries])

    %{state | entries: Map.merge(entries, persist_entries)}
  end

  defp exec_callback(handler, fun, args) do
    try do
      apply(handler, fun, args)
    rescue
      error ->
        Logger.error(exec_callback_fail: error)
        {:error, error}
    end
  end

  def subscribe(server, client_pid) when is_pid(client_pid) do
    :pg.join(GCChat, server, client_pid)
  end

  def get_client_nodes(handler) do
    :pg.get_members(GCChat, handler) |> Enum.map(&node/1)
  end

  @callback now() :: integer()
  @callback dump(id :: integer(), entries :: GCChat.Entry.entries()) :: :ok
  @callback get_from_db(GCChat.Entry.name()) :: {:ok, nil | GCChat.Entry.t()}

  defmacro(__using__(opts)) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour GCChat.Server
      @opts GCChat.Server.parse_opts(opts)
      @persist_interval Keyword.get(@opts, :persist_interval)
      @loop_interval 1000
      @handler __MODULE__
      use Memoize
      require Logger

      @impl true
      def handle_init(%{id: id}) do
        :pg.join(GCChat, "hh", self())
        %GCChat.Server{id: id, handler: __MODULE__}
      end

      def m() do
        %{
          local:
            :pg.get_members(GCChat, "hh")
            |> Enum.group_by(&node/1)
            |> Enum.map(&{elem(&1, 0), length(elem(&1, 1))})
            |> Enum.into(%{}),
          all: :pg.get_members(GCChat, "hh") |> length(),
          registry: Horde.Registry.count(@horde_registry_name)
        }
      end

      @impl true
      def handle_continue(state) do
        loop()
        loop_persist(@persist_interval)
        state
      end

      defp loop() do
        Process.send_after(self(), :loop, @loop_interval)
      end

      defp loop_persist(persist_interval) do
        Process.send_after(self(), :loop_persist, persist_interval)
      end

      @impl true
      def handle_call({:rpc, fun, fun_args}, state) do
        fun.(state, fun_args) |> IO.inspect(label: "rpc_result")
      end

      @impl true
      def handle_cast({:cast, fun, fun_args}, state) do
        fun.(state, fun_args) |> IO.inspect(label: "cast_result")
      end

      @impl true
      def handle_info(:loop, state) do
        loop()
        maybe_drop_expired_entries(state)
      end

      def handle_info(:loop_persist, %M{} = state) do
        loop_persist(@persist_interval)
        maybe_persist_entries(state)
      end

      defdelegate maybe_drop_expired_entries(state), to: GCChat.Server
      defdelegate maybe_persist_entries(state), to: GCChat.Server

      def subscribe(client_pid), do: GCChat.Server.subscribe(__MODULE__, client_pid)

      def get_client_nodes(), do: GCChat.Server.get_client_nodes(__MODULE__)

      defmemo fetch_entry(entry_name) do
        GCChat.Server.fetch_entry(__MODULE__, entry_name)
      end

      def invalidate_fetch_entry_memo(entry_names) do
        Enum.each(entry_names, &Memoize.invalidate(__MODULE__, :fetch_entry, [&1]))
      end

      def all_ready?() do
        Horde.Registry.count(@horde_registry_name) == @worker_num
      end

      @imple true
      def worker(entry_name) do
        (:erlang.phash2(entry_name, @worker_num) + 1)
        |> @worker_name.via()
      end

      def pick_worker(entry_name) do
        worker(entry_name) |> GenServer.whereis()
      end

      @impl true
      def now(), do: System.os_time(:second)

      @impl true
      def dump(_worker_id, _entries), do: :ok

      @impl true
      def get_from_db(entry_name), do: {:ok, nil}

      defoverridable now: 0, dump: 2, get_from_db: 1
    end
  end
end
