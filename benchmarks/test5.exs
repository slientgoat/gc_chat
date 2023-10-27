:ok = LocalCluster.start()
[_n1 | _] = LocalCluster.start_nodes("gc-chat-cluster", 2)

IO.puts("Nodes connected count #{Node.list() |> Enum.count()}")
IO.puts("---------------------------------------------------")

hello = fn -> File.open("a.txt", [:read, :write], fn io_dev -> IO.puts(io_dev, "hello") end) end
world = fn -> File.open("a.txt", [:read, :write], fn io_dev -> IO.puts(io_dev, "world") end) end

Benchee.run(
  %{
    "helloworld" => fn ->
      Task.async(hello)
      Task.async(world)
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
