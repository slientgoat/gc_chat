defmodule GcChat.Adapter.Persistence do
  @callback dump([%GCChat.Message{}]) :: :ok | {:error, term}

  @callback load() :: :ok | {:error, term}

  alias Nebulex.Entry

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Nebulex.Adapter.Persistence

      # sobelow_skip ["Traversal.FileModule"]
      @impl true
      def dump(msgs, opts) do
        path
        |> File.open([:read, :write], fn io_dev ->
          nil
          |> cache.stream(return: :entry)
          |> Stream.filter(&(not Entry.expired?(&1)))
          |> Stream.map(&{&1.key, &1.value})
          |> Stream.chunk_every(Keyword.get(opts, :entries_per_line, 10))
          |> Enum.each(fn entries ->
            bin = Entry.encode(entries, get_compression(opts))
            :ok = IO.puts(io_dev, bin)
          end)
        end)
        |> handle_response()
      end

      # sobelow_skip ["Traversal.FileModule"]
      @impl true
      def load(%{cache: cache}, path, opts) do
        path
        |> File.open([:read], fn io_dev ->
          io_dev
          |> IO.stream(:line)
          |> Stream.map(&String.trim/1)
          |> Enum.each(fn line ->
            entries = Entry.decode(line, [:safe])
            cache.put_all(entries, opts)
          end)
        end)
        |> handle_response()
      end

      defoverridable dump: 3, load: 3

      ## Helpers

      defp handle_response({:ok, _}), do: :ok
      defp handle_response({:error, _} = error), do: error

      defp get_compression(opts) do
        case Keyword.get(opts, :compression) do
          value when is_integer(value) and value >= 0 and value < 10 ->
            [compressed: value]

          _ ->
            [:compressed]
        end
      end
    end
  end
end
