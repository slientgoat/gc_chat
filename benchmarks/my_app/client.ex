defmodule MyApp.Client do
  use GCChat, server: MyApp.Server

  def now(), do: System.os_time(:second)
end
