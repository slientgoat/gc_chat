defmodule GCChat.ServerManager do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple())
  end

  def via_tuple(),
    do: {:via, Horde.Registry, {GCChat.GlobalRegistry, __MODULE__}}

  @impl true
  def init(opts) do
    pool_size = opts[:pool_size]
    Process.flag(:trap_exit, true)
    {:ok, _} = DynamicSupervisor.start_link(name: dynamic_supervisor_name())

    Enum.map(1..pool_size, fn id ->
      opts = Keyword.put(opts, :id, id)
      {:ok, pid} = DynamicSupervisor.start_child(dynamic_supervisor_name(), {GCChat.Server, opts})
      {id, pid}
    end)

    {:ok, opts}
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
end
