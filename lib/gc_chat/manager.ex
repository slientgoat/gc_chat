defmodule GCChat.Manager do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    with true <- distributedSupervisor_started?() || {:error, :distributedSupervisor_not_start},
         {:ok, _writter} <- start_global_service(GCChat.Writter) do
      #  {:ok, _reader} <- start_global_service(GCChat.Reader) do
      {:ok, [], {:continue, nil}}
    else
      {:error, error} ->
        {:stop, error}
    end
  end

  defp start_global_service(mod) do
    case Horde.DynamicSupervisor.start_child(GCChat.DistributedSupervisor, mod) do
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

  @impl true
  def handle_continue(nil, state) do
    {:noreply, state}
  end

  def distributedSupervisor_started?() do
    GCChat.DistributedSupervisor |> GenServer.whereis() |> is_pid()
  end
end
