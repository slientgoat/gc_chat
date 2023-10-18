defmodule BenchTestApplication do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BenchTestApplication.Supervisor]
    # Supervisor.start_link(, opts)
    children = [
      GCChat.HordeCache,
      GCChat.LocalCache,
      {Horde.Registry, [name: GCChat.GlobalRegistry, keys: :unique, members: :auto]},
      {
        Horde.DynamicSupervisor,
        [
          name: GCChat.DistributedSupervisor,
          strategy: :one_for_one,
          members: :auto
        ]
      },
      {BenchTest.Global, []}
    ]

    Supervisor.start_link(children, opts)
  end
end
