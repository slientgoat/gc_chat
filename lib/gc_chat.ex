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

  def supervisor_started?() do
    GCChat.DistributedSupervisor |> GenServer.whereis() |> is_pid()
  end

  def start_global_service({mod, _} = child_spec) do
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

  def lookup(cache_adapter, channel, last_id) do
    if cb = cache_adapter.get(channel) do
      GCChat.Entry.take(cb, last_id)
    else
      []
    end
  end

  def newest_id(cache_adapter, channel) do
    if cb = cache_adapter.get(channel) do
      GCChat.Entry.get_last_id(cb)
    else
      nil
    end
  end

  def delete_channel(chat_type, channel) do
    GCChat.Server.delete_channels(chat_type, [channel])
  end

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use GenServer
      @opts GCChat.parse_opts(opts)
      @persist Keyword.get(@opts, :persist)
      @persist_interval Keyword.get(@opts, :persist_interval)
      @batch_size Keyword.get(@opts, :batch_size)
      @submit_interval Keyword.get(@opts, :submit_interval)
      @cache_adapter Keyword.get(@opts, :cache_adapter)

      defdelegate build(attrs), to: GCChat.Message

      def send({:ok, %GCChat.Message{} = msg}) do
        send(msg)
      end

      def send(%GCChat.Message{} = msg) do
        cast({:send, msg})
      end

      def send(error) do
        {:error, error}
      end

      def lookup(channel, last_id) do
        GCChat.lookup(@cache_adapter, channel, last_id)
      end

      def newest_id(channel) do
        GCChat.newest_id(@cache_adapter, channel)
      end

      def delete_channel(channel) do
        GCChat.delete_channel(__MODULE__, channel)
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

      def start_link(_) do
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
      end

      @impl true
      def init(_) do
        opts = [
          chat_type: __MODULE__,
          persist: @persist,
          persist_interval: @persist_interval,
          pool_size: System.schedulers_online()
        ]

        with true <- GCChat.supervisor_started?() || {:error, :superviso_not_started},
             {:ok, pid} <- GCChat.start_global_service({GCChat.ServerManager, opts}) do
          {:ok, [], {:continue, :initialize}}
        else
          {:error, error} ->
            {:stop, error}
        end
      end

      @impl true
      def handle_continue(:initialize, msgs) do
        loop_submit()
        {:noreply, msgs}
      end

      @impl true
      def handle_info(:loop_submit, []) do
        loop_submit()
        {:noreply, []}
      end

      def handle_info(:loop_submit, msgs) do
        {msgs, t} = Enum.split(msgs, -@batch_size)
        GCChat.Server.send(__MODULE__, t |> Enum.reverse())
        loop_submit()
        {:noreply, msgs}
      end

      @impl true
      def handle_cast({:send, msg}, msgs) do
        {:noreply, [msg | msgs]}
      end

      defp loop_submit() do
        Process.send_after(self(), :loop_submit, @submit_interval)
      end

      defp loop_garbage() do
        Process.send_after(self(), :loop_garbage, @submit_interval)
      end
    end
  end
end
