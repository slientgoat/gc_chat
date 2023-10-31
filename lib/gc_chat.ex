defmodule GCChat do
  @opts_schema [
    persist: [
      type: :boolean,
      doc: "persist data to local node disk after application stop and persist_interval",
      default: false
    ],
    persist_interval: [
      type: :non_neg_integer,
      doc: "persist data for every [persist_interval] seconds",
      default: 60
    ],
    batch_size: [
      type: {:in, 1..10000},
      doc: "submit max [batch_size] msgs to server per time",
      default: 200
    ],
    server_pool_size: [
      type: :non_neg_integer,
      doc: "the pool size of server worker. default: System.schedulers_online()"
    ],
    submit_interval: [
      type: {:in, 10..3000},
      doc: "submit msgs to the server per [submit_interval] ms",
      default: 100
    ],
    cache_adapter: [
      type: :atom,
      doc: "where msgs to cache",
      default: GCChat.LocalCache,
      required: true
    ]
  ]

  def parse_opts(opts) do
    {:ok, default} = NimbleOptions.validate(opts, @opts_schema)
    default
  end

  def lookup(cache_adapter, channel_name, last_id) do
    cache_adapter.get(channel_name) |> GCChat.Entry.lookup(last_id)
  end

  def newest_id(cache_adapter, entry_name) do
    if entry = cache_adapter.get(entry_name) do
      GCChat.Entry.last_id(entry)
    else
      nil
    end
  end

  def group_msgs(msgs, server_pool_size) do
    msgs
    |> Enum.group_by(&GCChat.ServerManager.choose_worker(&1.channel, server_pool_size))
  end

  def submit_msgs(grouped_msgs, batch_size) do
    grouped_msgs
    |> Enum.reduce([], fn {worker, list}, acc ->
      if is_pid(GenServer.whereis(worker)) do
        list
        |> Enum.reverse()
        |> Enum.chunk_every(batch_size)
        |> Enum.each(&GCChat.Server.send(worker, &1))

        acc
      else
        Enum.reverse(list) ++ acc
      end
    end)
    |> Enum.reverse()
  end

  def delete_entries(channel_names, server_pool_size) do
    channel_names
    |> Enum.group_by(&GCChat.ServerManager.choose_worker(&1, server_pool_size))
    |> Enum.reduce([], fn {worker, list}, acc ->
      if is_pid(worker) do
        GCChat.Server.delete_entries(worker, list)
        acc
      else
        list ++ acc
      end
    end)
  end

  @callback now() :: integer()
  @callback dump(id :: integer(), entries :: GCChat.Entry.entries()) :: :ok
  @callback get_from_db(GCChat.Entry.name()) :: {:ok, nil | GCChat.Entry.t()}

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use GenServer
      use Memoize
      @behaviour GCChat
      @opts GCChat.parse_opts(opts)
      @persist Keyword.get(@opts, :persist)
      @persist_interval Keyword.get(@opts, :persist_interval)
      @batch_size Keyword.get(@opts, :batch_size)
      @submit_interval Keyword.get(@opts, :submit_interval)
      @cache_adapter Keyword.get(@opts, :cache_adapter)
      @otp_app Keyword.get(@opts, :otp_app)

      defdelegate build(attrs), to: GCChat.Message
      defdelegate encode_entry_name(chat_type, tag), to: GCChat.Entry, as: :encode_name
      defdelegate decode_entry_name(entry_name), to: GCChat.Entry, as: :decode_name

      def send({:ok, %GCChat.Message{} = msg}) do
        send(msg)
      end

      def send(%GCChat.Message{} = msg) do
        cast({:send, msg})
      end

      def send(error) do
        {:error, error}
      end

      def lookup(entry_name, last_id) do
        GCChat.lookup(@cache_adapter, entry_name, last_id)
      end

      def lookup_from_memorize(entry_name, last_id) do
        fetch_entry(entry_name)
        |> GCChat.Entry.lookup(last_id)
      end

      defmemo fetch_entry(entry_name) do
        GCChat.ServerManager.choose_worker(entry_name, get_server_pool_size())
        |> GCChat.Server.fetch_entry(entry_name)
      end

      def invalidate_fetch_entry_memo(entry_names) do
        Enum.each(entry_names, &Memoize.invalidate(__MODULE__, :fetch_entry, [&1]))
      end

      def newest_id(entry_name) do
        GCChat.newest_id(@cache_adapter, entry_name)
      end

      def delete_entry(entry_name) do
        GCChat.delete_entries([entry_name], get_server_pool_size())
      end

      def cache_adapter() do
        @cache_adapter
      end

      def pid() do
        __MODULE__ |> GenServer.whereis()
      end

      def cast(event) do
        if pid = pid() do
          GenServer.cast(pid, event)
          :ok
        else
          :error
        end
      end

      def server() do
        GCChat.Server.pid(__MODULE__)
      end

      def nodes() do
        :pg.get_members(GCChat, __MODULE__) |> Enum.map(&node/1)
      end

      def start_link(_) do
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
      end

      @impl true
      def init(_) do
        opts = Keyword.put(@opts, :instance, __MODULE__)

        with true <- supervisor_started?() || {:error, :superviso_not_started},
             {:ok, pid} <- start_global_service({GCChat.ServerManager, opts}) do
          GCChat.ServerManager.pool_size(pid)
          |> put_server_pool_size()

          {:ok, [], {:continue, :initialize}}
        else
          {:error, error} ->
            {:stop, error}
        end
      end

      def supervisor_started?() do
        GCChat.DistributedSupervisor |> GenServer.whereis() |> is_pid()
      end

      defp start_global_service({mod, _} = child_spec) do
        case Horde.DynamicSupervisor.start_child(GCChat.DistributedSupervisor, child_spec) do
          {:ok, pid} ->
            {:ok, pid}

          {:error, {:already_started, pid}} ->
            {:ok, pid}

          :ignore ->
            {:ok, mod.pid()}

          {:error, error} ->
            {:error, error}
        end
      end

      def put_server_pool_size(server_pool_size) do
        :persistent_term.put({__MODULE__, :server_pool_size}, server_pool_size)
      end

      def get_server_pool_size() do
        :persistent_term.get({__MODULE__, :server_pool_size})
      end

      @impl true
      def handle_continue(:initialize, msgs) do
        :pg.join(GCChat, __MODULE__, self())
        loop_submit()
        {:noreply, msgs}
      end

      @impl true
      def handle_info(:loop_submit, []) do
        loop_submit()
        {:noreply, []}
      end

      def handle_info(:loop_submit, msgs) do
        rest =
          GCChat.group_msgs(msgs, get_server_pool_size())
          |> GCChat.submit_msgs(@batch_size)

        loop_submit()
        {:noreply, rest}
      end

      @impl true
      def handle_cast({:send, msg}, msgs) do
        {:noreply, [msg | msgs]}
      end

      defp loop_submit() do
        Process.send_after(self(), :loop_submit, @submit_interval)
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
