defmodule GCChat.Entry do
  defstruct name: nil,
            cb: nil,
            last_id: 0,
            ttl: nil,
            touched_at: nil,
            updated_at: nil,
            created_at: nil,
            enable_persist: false

  @type t :: %__MODULE__{
          name: GCChat.Message.channel(),
          cb: CircularBuffer.t(),
          last_id: non_neg_integer(),
          ttl: non_neg_integer(),
          touched_at: non_neg_integer(),
          updated_at: non_neg_integer(),
          created_at: non_neg_integer(),
          enable_persist: boolean()
        }

  defmodule Message do
    defstruct id: nil,
              body: nil,
              from: nil,
              send_at: nil
  end

  @type entries :: %{GCChat.Message.channel() => t()}
  alias __MODULE__, as: M

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
        name,
        now,
        %GCChat.Config{buffer_size: buffer_size, ttl: ttl} = config
      ) do
    cb = CircularBuffer.new(buffer_size)
    enable_persist = GCChat.Config.enable_persist?(config)

    %M{
      name: name,
      cb: cb,
      ttl: ttl,
      touched_at: now,
      updated_at: now,
      created_at: now,
      enable_persist: enable_persist
    }
  end

  def update_cb(entry, cb), do: %M{entry | cb: cb}
  def update_last_id(entry, last_id), do: %M{entry | last_id: last_id}
  def update_updated_at(entry, updated_at), do: %M{entry | updated_at: updated_at}
  def update_touched_at(entry, touched_at), do: %M{entry | touched_at: touched_at}

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

  def persist?(%M{enable_persist: enable_persist}) do
    enable_persist
  end
end
