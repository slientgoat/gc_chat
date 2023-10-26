:ok = LocalCluster.start()
[_n1, _n2 | _] = LocalCluster.start_nodes("gc-chat-cluster", 2)

server_name = GCChat.ServerManager.via_tuple()
IO.puts("waitting for #{inspect(server_name)} start")
fn_server_pid = fn -> GenServer.whereis(server_name) end
GCChat.TestFixtures.wait_for_server_started(fn_server_pid)

server_pid = fn_server_pid.()
IO.puts("#{inspect(server_name)} start at #{node(server_pid)} success!")
ExUnit.start()
