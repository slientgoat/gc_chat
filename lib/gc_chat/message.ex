defmodule GCChat.Message do
  use Ecto.Schema
  import Ecto.Changeset
  alias GCChat.Message, as: M
  @type channel :: String.t()
  schema "chat_message" do
    field(:chat_type, :integer)
    field(:channel, :string)
    field(:from, :integer)
    field(:send_at, :integer)
    field(:body, :string)
  end

  @require_fields ~w(chat_type channel from send_at body)a
  @cast_fields @require_fields

  def require_fields(), do: @require_fields
  def cast_fields(), do: @cast_fields

  @spec build(map) :: {:error, Ecto.Changeset.t()} | {:ok, %M{}}
  def build(attrs) when is_map(attrs) do
    attrs
    |> validate_attrs()
  end

  def validate(fun, attrs) do
    %M{}
    |> cast(attrs, @cast_fields)
    |> then(&apply(fun, [&1]))
    |> apply_action(:validate)
  end

  defp validate_attrs(attrs) do
    attrs
    |> setup_common_attrs(@cast_fields)
    |> validate_required(@require_fields)
    |> validate_body()
    |> apply_action(:validate)
  end

  defp setup_common_attrs(attrs, fields) do
    attrs
    |> ensure_common_attrs()
    |> then(&cast(%M{}, &1, fields))
  end

  defp ensure_common_attrs(attrs) do
    attrs
    |> ensure_key_exist(:send_at, System.os_time(:second))
  end

  defp ensure_key_exist(attrs, key, default) do
    Enum.into(attrs, Map.new([{key, default}]))
  end

  def validate_body(changeset) do
    changeset
    |> validate_length(:body, min: 0, max: max_body_length())
  end

  def max_body_length(), do: 4000
end
