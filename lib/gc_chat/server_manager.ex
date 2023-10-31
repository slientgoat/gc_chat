defmodule GCChat.ServerManager do
  use GenServer
  require Logger
  defstruct pool_size: nil, instance: nil

  def choose_worker(channel, pool_size) do
    :erlang.phash2(channel, pool_size)
    |> GCChat.Server.via_tuple()
  end

  def pool_size(pid \\ via_tuple()) do
    GenServer.call(pid, :pool_size)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple())
  end

  def pid() do
    GenServer.whereis(via_tuple())
  end

  def via_tuple(),
    do: {:via, Horde.Registry, {GCChat.GlobalRegistry, __MODULE__}}

  @impl true
  def init(opts) do
    pool_size = Keyword.get(opts, :server_pool_size, nil) || System.schedulers_online()

    Process.flag(:trap_exit, true)
    {:ok, _} = DynamicSupervisor.start_link(name: dynamic_supervisor_name())

    Enum.map(1..pool_size, fn id ->
      opts = Keyword.put(opts, :id, id)
      {:ok, pid} = DynamicSupervisor.start_child(dynamic_supervisor_name(), {GCChat.Server, opts})
      {id, pid}
    end)

    instance = Keyword.get(opts, :instance)
    {:ok, %GCChat.ServerManager{pool_size: pool_size, instance: instance}}
  end

  def dynamic_supervisor_name() do
    :"#{__MODULE__}.DynamicSupervisor"
  end

  @impl true
  def handle_info(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, pid, {:name_conflict, _, _, _}}, state) do
    Logger.warning("Name conflict. Stopping this process #{inspect(pid)}...")

    {:stop, :normal, state}
  end

  def handle_info({:EXIT, _pid, _reason}, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_call(:pool_size, _from, %GCChat.ServerManager{pool_size: pool_size} = state) do
    {:reply, pool_size, state}
  end
end
