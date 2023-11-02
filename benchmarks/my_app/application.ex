defmodule MyApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]

    topologies = [
      game_server: [
        strategy: Cluster.Strategy.Gossip
      ]
    ]

    # Supervisor.start_link(, opts)
    children = [
      %{id: :pg, start: {:pg, :start_link, [GCChat]}},
      {Cluster.Supervisor, [topologies, [name: Matrix.ClusterSupervisor]]},
      {Horde.Registry, [name: Matrix.GlobalRegistry, keys: :unique, members: :auto]},
      MyApp.Client,
      MyApp.Server
    ]

    Supervisor.start_link(children, opts)
  end
end
