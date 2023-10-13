defmodule GCChat.Handler do
  use GenServer
  require Logger

  def send_msgs(msgs) do
    GenServer.cast(via_tuple(__MODULE__), {:send_msgs, msgs})
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
    case GenServer.start_link(__MODULE__, [], name: via_tuple(name)) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.info("already started at #{inspect(pid)}, returning :ignore")
        :ignore
    end
  end

  @impl true
  def init(_args) do
    {:ok, nil}
  end

  def via_tuple(name), do: {:via, Horde.Registry, {GCChat.GlobalRegistry, name}}

  @impl true
  def handle_cast({:send_msgs, msgs}, state) do
    brodcast(msgs)
    {:noreply, state}
  end

  def brodcast(msgs) do
    group_by_channel(msgs)
    |> Enum.each(fn {c, msgs} ->
      GCChat.Channel.cast(c, msgs)
    end)
  end

  def group_by_channel(msgs) do
    msgs |> Enum.group_by(& &1.channel)
  end
end
