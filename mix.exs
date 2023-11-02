defmodule GCChat.MixProject do
  use Mix.Project

  def project do
    [
      app: :gc_chat,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.

  if Mix.env() == :test do
    def application do
      [
        mod: {MyApp.Application, []},
        extra_applications: [:runtime_tools, :observer, :wx]
      ]
    end
  else
    def application do
      []
    end
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "benchmarks"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:libcluster, "~> 3.3", only: [:dev, :test]},
      {:ecto, "~> 3.10.0"},
      {:enum_type, "~> 1.1.0"},
      {:circular_buffer, "~> 0.4.1"},
      {:easy_horde, git: "http://192.168.15.11:9000/game_public/easy_horde.git", only: [:test]},
      {:nebulex, "~> 2.5"},
      {:shards, "~> 1.0"},
      {:decorator, "~> 1.4"},
      {:telemetry, "~> 1.0"},
      {:memoize, "~> 1.4"},
      {:nimble_options, "~> 1.0"},
      {:benchee, "~> 1.1", only: [:dev, :test]},
      {:local_cluster, "~> 1.2", only: [:test]},
      {:mix_test_watch, "~> 1.1", only: [:test], runtime: false}
    ]
  end
end
