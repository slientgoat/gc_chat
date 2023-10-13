defmodule GCChat.Channel do
  defstruct channel: nil

  def start_child(mod) do
    case Horde.DynamicSupervisor.start_child(GCChat.DistributedSupervisor, mod) do
      {:ok, pid} ->
        {:ok, pid}

      :ignore ->
        {:ok, mod.pid}

      {:error, error} ->
        raise inspect(error)
    end
  end

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use GenServer
      @opts opts

      def send(msg) do
        GenServer.cast(__MODULE__, {:receive_msg, msg})
      end

      @loop_interval 100

      def start_link(_) do
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
      end

      @impl true
      def init(_) do
        [
          GCChat.Writter,
          GCChat.Reader
        ]

        writter = GCChat.Channel.start_child(GCChat.Writter)
        reader = GCChat.Channel.start_child(GCChat.Reader)

        {:ok, [], {:continue, nil}}
      end

      @impl true
      def handle_continue(nil, msgs) do
        Process.send_after(self(), :loop, @loop_interval)
        {:noreply, msgs}
      end

      @impl true
      def handle_info(:loop, msgs) do
        {:noreply, []}
      end

      @impl true
      def handle_cast({:receive_msg, msg}, msgs) do
        {:noreply, [msg | msgs]}
      end
    end
  end
end
