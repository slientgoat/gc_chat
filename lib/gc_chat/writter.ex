defmodule GCChat.Writter do
  use GenServer

  def child_spec(opts) do
    name = Keyword.get(opts, :name, __MODULE__)

    %{
      id: "#{__MODULE__}_#{name}",
      start: {__MODULE__, :start_link, [name]},
      shutdown: 10_000,
      restart: :transient
    }
  end

  def pid() do
    via_tuple() |> GenServer.whereis()
  end

  def start_link(name) do
    case GenServer.start_link(__MODULE__, [], name: via_tuple(name)) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, _pid}} ->
        :ignore
    end
  end

  @channel_public "public"

  @impl true
  def init(_args) do
    :ets.new(__MODULE__, [:named_table, read_concurrency: true])
    :ets.insert(__MODULE__, {@channel_public, GCChat.create_buffer(1000)})
    {:ok, nil}
  end

  def insert(key, val) do
    :ets.insert(__MODULE__, {key, val})
  end

  def via_tuple(), do: via_tuple(__MODULE__)
  def via_tuple(name), do: {:via, Horde.Registry, {GCChat.GlobalRegistry, name}}

  @impl true
  def handle_call({:lookup, channel, i}, _from, state) do
    reply = do_lookup(channel, i)

    {:reply, reply, state}
  end

  defp do_lookup(channel, i) do
    :ets.lookup(__MODULE__, channel)
    |> case do
      [{_, v}] ->
        GCChat.find(v, i)

      _ ->
        []
    end
  end
end
