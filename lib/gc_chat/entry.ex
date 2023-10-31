defmodule GCChat.Entry do
  defstruct name: nil,
            cb: nil,
            last_id: 0,
            ttl: nil,
            touched_at: nil,
            updated_at: nil,
            created_at: nil,
            persist_at: nil

  @type name :: String.t()
  @type t :: %__MODULE__{
          name: name(),
          cb: CircularBuffer.t(),
          last_id: non_neg_integer(),
          ttl: non_neg_integer(),
          touched_at: non_neg_integer(),
          updated_at: non_neg_integer(),
          created_at: non_neg_integer(),
          persist_at: non_neg_integer()
        }

  defmodule Message do
    defstruct id: nil,
              body: nil,
              from: nil,
              send_at: nil
  end

  @type entries :: %{name() => t()}
  alias __MODULE__, as: M

  def encode_name(chat_type, channel) do
    "#{chat_type}|#{channel}"
  end

  def decode_name(entry_name) do
    [chat_type, channel | _] = String.split(entry_name, "|")
    {String.to_integer(chat_type), channel}
  end

  def lookup(entry, last_id) do
    case entry do
      %M{} = e ->
        take(e, last_id)

      _ ->
        []
    end
  end

  def take(%M{cb: cb}, last_id) when is_integer(last_id) and last_id >= 0 do
    n = CircularBuffer.newest(cb)
    CircularBuffer.to_list(cb) |> Enum.take(last_id - n.id)
  end

  def last_id(%M{last_id: last_id}) do
    last_id
  end

  def circular_buffer(%M{cb: cb}) do
    cb
  end

  def push(%M{cb: cb, last_id: last_id} = entry, %GCChat.Message{} = msg, now) do
    id = last_id + 1
    val = msg |> Map.from_struct() |> then(&struct(Message, &1)) |> Map.put(:id, id)

    entry
    |> update_cb(CircularBuffer.insert(cb, val))
    |> update_last_id(id)
    |> update_updated_at(now)
    |> update_touched_at(now)
  end

  def new(
        entry_name,
        now,
        %GCChat.Config{buffer_size: buffer_size, ttl: ttl} = config
      ) do
    cb = CircularBuffer.new(buffer_size)
    enable_persist = GCChat.Config.enable_persist?(config)

    %M{
      name: entry_name,
      cb: cb,
      ttl: ttl,
      touched_at: now,
      updated_at: now,
      created_at: now,
      persist_at: init_persist_at(enable_persist, now)
    }
  end

  def init_persist_at(enable_persist, now) do
    if enable_persist do
      now
    else
      nil
    end
  end

  def update_cb(entry, cb), do: %M{entry | cb: cb}
  def update_last_id(entry, last_id), do: %M{entry | last_id: last_id}
  def update_updated_at(entry, updated_at), do: %M{entry | updated_at: updated_at}
  def update_touched_at(entry, touched_at), do: %M{entry | touched_at: touched_at}
  def update_persist_at(entry, persist_at), do: %M{entry | persist_at: persist_at}

  @spec find_expired_entry_names(entries(), non_neg_integer()) :: [name()]
  def find_expired_entry_names(entries, now) do
    Enum.reduce(entries, [], fn {_, %M{name: name} = x}, acc ->
      if expired?(x, now) do
        [name | acc]
      else
        acc
      end
    end)
  end

  def expired?(%M{ttl: :infinity}, _now) do
    false
  end

  def expired?(%M{ttl: ttl, touched_at: touched_at, updated_at: updated_at}, now) do
    cond do
      now >= touched_at + ttl ->
        true

      now >= updated_at + ttl + 86400 ->
        true

      true ->
        false
    end
  end

  @spec find_persist_entry_names(entries()) :: [name()]
  def find_persist_entry_names(entries) do
    Enum.reduce(entries, [], fn {_, %M{name: name} = x}, acc ->
      if persist?(x) do
        [name | acc]
      else
        acc
      end
    end)
  end

  def persist?(%M{persist_at: nil}), do: false

  def persist?(%M{persist_at: persist_at, updated_at: updated_at}), do: updated_at > persist_at
end
