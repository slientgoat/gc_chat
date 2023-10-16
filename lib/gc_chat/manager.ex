defmodule GCChat.Manager do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    with {:ok, writter} <- start_global_service(GCChat.Writter),
         {:ok, reader} <- start_global_service(GCChat.Reader) do
      :persistent_term.put({__MODULE__, :writter}, writter)
      :persistent_term.put({__MODULE__, :reader}, reader)
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
end
