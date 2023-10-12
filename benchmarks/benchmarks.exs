# Benchee.run(
#   %{
#     "deliver" => fn ->
#       SimpleHandler.deliver(
#         SimpleHandler.build_personal_message(%{
#           cfg_id: 1,
#           from: 123,
#           to: System.unique_integer([:positive])
#         })
#         |> elem(1)
#       )
#     end,
#     "pull_global_ids" => fn ->
#       SimpleHandler.pull_message_ids(1, 1)
#     end
#   },
#   formatters: [
#     {Benchee.Formatters.Console, comparison: false, extended_statistics: true}
#     # {Benchee.Formatters.HTML, extended_statistics: true, auto_open: false}
#   ],
#   print: [
#     fast_warning: false
#   ]
# )
