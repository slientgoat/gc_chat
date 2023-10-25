:ok = LocalCluster.start()
[_n1 | _] = LocalCluster.start_nodes("gc-chat-cluster", 2)

IO.puts("Nodes connected count #{Node.list() |> Enum.count()}")
IO.puts("---------------------------------------------------")

fn_server_pid = fn -> GenServer.whereis(GCChat.ServerManager.via_tuple()) end

Benchee.run(
  %{
    "GCChat.Server.pid(1)" => fn ->
      GCChat.Server.pid(1)
    end
  },
  time: 10,
  before_scenario: fn x ->
    server_name = inspect(GCChat.ServerManager.via_tuple())
    IO.puts("waitting for #{server_name} start")

    GCChat.TestFixtures.wait_for_server_started(fn_server_pid)

    IO.puts("#{server_name} start success!")

    IO.puts(
      "Current scenario is run at [#{inspect(self())}],and #{server_name} is run at [#{inspect(node(fn_server_pid.()))}] "
    )

    x
  end
)
