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
        mod: {BenchTestApplication, []}
      ]
    end
  else
    def application do
      [
        mod: {GCChat.Application, []}
      ]
    end
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "benchmarks"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.10.0"},
      {:enum_type, "~> 1.1.0"},
      {:circular_buffer, "~> 0.4.1"},
      {:nebulex, "~> 2.5"},
      {:shards, "~> 1.0"},
      {:decorator, "~> 1.4"},
      {:telemetry, "~> 1.0"},
      {:nebulex_adapters_horde, "~> 1.0"},
      {:nimble_options, "~> 1.0"},
      {:benchee, "~> 1.1", only: [:dev, :test]},
      {:local_cluster, "~> 1.2", only: [:test]},
      {:mix_test_watch, "~> 1.1", only: [:test], runtime: false}
    ]
  end
end
