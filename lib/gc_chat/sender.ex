defmodule GCChat.Sender do
  @moduledoc """
  Documentation for `GCChat`.
  """
  use GenServer

  def send(msg) do
    GenServer.cast(__MODULE__, {:receive_msg, msg})
  end

  @loop_interval 100

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args)
  end

  @impl true
  def init(_) do
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
