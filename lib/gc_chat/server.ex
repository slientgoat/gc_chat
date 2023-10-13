defmodule GCChat.Server do
  @moduledoc """
  Documentation for `GCChat`.
  """
  use GenServer

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args)
  end

  @channel_public "public"

  @impl true
  def init(_) do
    :ets.new(__MODULE__, [:named_table, read_concurrency: true])
    :ets.insert(__MODULE__, {@channel_public, create_buffer(1000)})
    {:ok, nil, {:continue, nil}}
  end

  @impl true
  def handle_continue(_, state) do
    IO.inspect(%{node: Node.self(), pid: self()})
    {:noreply, state}
  end

  def send(_attrs) do
    :ok
  end

  def create_buffer(x) do
    Enum.to_list(1..x)
    |> Enum.reduce(CircularBuffer.new(x), fn i, acc ->
      CircularBuffer.insert(acc, i)
    end)
  end

  def lookup(i) do
    :ets.lookup(__MODULE__, @channel_public)
    |> case do
      [{_, v}] ->
        find(v, i)

      _ ->
        []
    end
  end

  defp find(cb, i) do
    n = CircularBuffer.newest(cb)
    CircularBuffer.to_list(cb) |> Enum.take(i - n)
  end
end
