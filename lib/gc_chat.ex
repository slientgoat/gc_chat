defmodule GCChat do
  @opts_schema [
    server: [
      type: :atom,
      doc: "the process that use easy_horde",
      required: true
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
    ]
  ]

  def parse_opts(opts) do
    {:ok, default} = NimbleOptions.validate(opts, @opts_schema)
    default
  end

  def submit_msgs(buffers, server, batch_size) do
    buffers
    |> Enum.reduce(%{}, fn {entry_name, msgs}, acc ->
      if is_pid(server.pick_worker(entry_name)) do
        msgs
        |> Enum.reverse()
        |> Enum.chunk_every(batch_size)
        |> Enum.each(
          &(GCChat.Server.send(server, entry_name, &1)
            |> IO.inspect(label: "submit_result"))
        )

        acc
      else
        Map.put(acc, entry_name, msgs)
      end
    end)
  end

  @callback now() :: integer()

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use GenServer
      @behaviour GCChat
      @opts GCChat.parse_opts(opts)
      @server Keyword.get(@opts, :server)
      @server_registry Module.concat(@server, Registry)
      @otp_app Keyword.get(@opts, :otp_app)
      @batch_size Keyword.get(@opts, :batch_size)
      @submit_interval Keyword.get(@opts, :submit_interval)

      defdelegate build(attrs), to: GCChat.Message
      defdelegate encode_entry_name(chat_type, tag), to: GCChat.Entry, as: :encode_name
      defdelegate decode_entry_name(entry_name), to: GCChat.Entry, as: :decode_name

      def opts(), do: @opts

      def send({:ok, %GCChat.Message{} = msg}) do
        send(msg)
      end

      def send(%GCChat.Message{} = msg) do
        IO.inspect("88")
        cast({:send, msg})
      end

      def send(error) do
        IO.inspect("66")
        {:error, error}
      end

      def lookup(entry_name, last_id) do
        fetch_entry(entry_name)
        |> GCChat.Entry.lookup(last_id)
      end

      def fetch_entry(entry_name) do
        @server.fetch_entry(entry_name)
      end

      def fetch_newest_id(entry_name) do
        if entry = fetch_entry(entry_name) do
          GCChat.Entry.last_id(entry)
        else
          nil
        end
      end

      defp cast(event) do
        IO.inspect("99")

        if pid = pid() do
          GenServer.cast(pid, event)
          :ok
        else
          :error
        end
      end

      defp pid() do
        __MODULE__ |> GenServer.whereis()
      end

      def nodes() do
        :pg.get_members(GCChat, __MODULE__) |> Enum.map(&node/1)
      end

      def start_link(_) do
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
      end

      @impl true
      def init(_) do
        {:ok, %{}, {:continue, :initialize}}
      end

      @impl true
      def handle_continue(:initialize, msgs) do
        wait_server_ready()
        :ok = @server.subscribe(self())
        loop_submit()
        {:noreply, msgs}
      end

      defp wait_server_ready() do
        if @server.all_ready?() do
          :ok
        else
          Process.sleep(100)
          wait_server_ready()
        end
      end

      @impl true
      def handle_info(:loop_submit, buffers) do
        rest = GCChat.submit_msgs(buffers, @server, @batch_size)

        loop_submit()
        {:noreply, rest}
      end

      @impl true
      def handle_cast({:send, msg}, buffers) do
        IO.inspect(msg, label: :push_into_buffers)
        {:noreply, push_into_buffers(buffers, msg)}
      end

      defp push_into_buffers(buffers, %GCChat.Message{} = msg) do
        entry_name = GCChat.Server.to_entry_name(msg)

        case Map.get(buffers, entry_name, nil) do
          nil ->
            Map.put(buffers, entry_name, [msg])

          msgs ->
            Map.put(buffers, entry_name, [msg | msgs])
        end
      end

      defp loop_submit() do
        Process.send_after(self(), :loop_submit, @submit_interval)
      end

      @impl true
      def now(), do: System.os_time(:second)

      defoverridable now: 0
    end
  end
end
