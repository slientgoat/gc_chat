defmodule GCChat.Entry do
  defstruct name: nil,
            cb: nil,
            last_id: 0,
            ttl: nil,
            touched_at: nil,
            updated_at: nil,
            created_at: nil,
            persisted_at: nil

  @type t :: %__MODULE__{
          name: GCChat.Message.channel(),
          cb: CircularBuffer.t(),
          last_id: non_neg_integer(),
          ttl: non_neg_integer(),
          touched_at: non_neg_integer(),
          updated_at: non_neg_integer(),
          created_at: non_neg_integer(),
          persisted_at: non_neg_integer()
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

  def push(%M{cb: cb, last_id: last_id} = m, %GCChat.Message{} = msg, now) do
    id = last_id + 1
    val = msg |> Map.from_struct() |> then(&struct(Message, &1)) |> Map.put(:id, id)
    cb = CircularBuffer.insert(cb, val)
    %M{m | cb: cb, last_id: id, updated_at: now, touched_at: now}
  end

  def new(
        name,
        now,
        %GCChat.Config{buffer_size: buffer_size, ttl: ttl} = config
      ) do
    cb = CircularBuffer.new(buffer_size)
    persisted_at = init_persisted_at(GCChat.Config.enable_persist?(config))

    %M{
      name: name,
      cb: cb,
      ttl: ttl,
      touched_at: now,
      updated_at: now,
      created_at: now,
      persisted_at: persisted_at
    }
  end

  defp init_persisted_at(enable_persist?) do
    if enable_persist? do
      0
    else
      nil
    end
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

  def persist?(%M{persisted_at: persisted_at}) do
    persisted_at != nil
  end
end
