defmodule GCChat.Message do
  use EnumType

  defenum Type do
    value(PersonalMessage, 1)
    default(PersonalMessage)
  end

  use Ecto.Schema
  import Ecto.Changeset
  alias GCChat.Message, as: M
  @primary_key {:id, :id, autogenerate: true}
  @type id :: integer()
  schema "message" do
    field(:type, Type)
    field(:cfg_id, :integer)
    field(:from, :integer)
    field(:to, :integer)
    field(:assigns, {:map, :string})
    field(:send_at, :integer)
    field(:ttl, :integer)
  end

  @common_fields ~w(id type from to assigns send_at ttl)a

  @require_fields %{
    Type.PersonalMessage => [:cfg_id, :from, :to]
  }

  @cast_fields for t <- Type.enums(), into: %{}, do: {t, @require_fields[t] ++ @common_fields}

  def require_fields(), do: @require_fields
  def cast_fields(), do: @cast_fields

  def validate(fun, attrs) do
    %M{}
    |> cast(
      attrs,
      ~w(type from to cfg_id assigns send_at ttl)a
    )
    |> then(&apply(fun, [&1]))
    |> apply_action(:validate)
  end

  @spec build_personal_message(map) :: {:error, Ecto.Changeset.t()} | {:ok, %M{}}
  def build_personal_message(attrs) when is_map(attrs) do
    attrs
    |> Map.put(:type, Type.PersonalMessage)
    |> validate_personal_message_attrs()
  end

  defp validate_personal_message_attrs(attrs) do
    validate_attrs(attrs, Type.PersonalMessage)
    |> apply_action(:validate)
  end

  defp validate_attrs(attrs, type) do
    cast_fields = @cast_fields[type]
    required_fields = @require_fields[type]

    attrs
    |> setup_common_attrs(cast_fields)
    |> validate_inclusion(:type, [type])
    |> validate_required(required_fields)
  end

  @required_fields ~w(type send_at ttl)a
  defp setup_common_attrs(attrs, fields) do
    attrs
    |> ensure_common_attrs()
    |> then(&cast(%M{}, &1, fields))
    |> validate_assigns()
    |> validate_required(@required_fields)
  end

  defp ensure_common_attrs(attrs) do
    attrs
    |> ensure_key_exist(:ttl, ttl())
    |> ensure_key_exist(:send_at, System.os_time(:second))
  end

  def ttl(), do: :persistent_term.get({__MODULE__, :ttl}, nil) || default_ttl()

  def default_ttl(), do: 90 * 86400

  def set_ttl(ttl) when is_integer(ttl), do: :persistent_term.put({__MODULE__, :ttl}, ttl)
  def set_ttl(_), do: :error

  defp ensure_key_exist(attrs, key, default) do
    Enum.into(attrs, Map.new([{key, default}]))
  end

  def validate_assigns(changeset) do
    changeset
    |> validate_length(:assigns, min: 0, max: max_assigns_length())
  end

  def max_assigns_length(), do: 100
end
