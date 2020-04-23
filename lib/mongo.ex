defmodule SevenottersMongo.Storage do
  @moduledoc false

  require Logger
  @behaviour SevenottersPersistence.Storage

  @bson_value_format ~r/^[A-Fa-f0-9\-]{24}$/
  @pool_size 10

  def start_link(opts \\ []) do
    Mongo.start_link(opts ++ [name: __MODULE__, pool_size: @pool_size])
  end

  @spec initialize(String.t()) :: any
  def initialize(_collection), do: nil

  @spec insert(String.t(), Map.t()) :: any
  def insert(collection, value) do
    {:ok, _id} = Mongo.insert_one(__MODULE__, collection, value)
  end

  @spec new_id :: any
  def new_id, do: Mongo.object_id()

  @spec printable_id(any) :: String.t()
  def printable_id(%BSON.ObjectId{} = id), do: BSON.ObjectId.encode!(id)
  def printable_id(id) when is_bitstring(id), do: id

  @spec object_id(String.t()) :: any
  def object_id(id) do
    {_, bin} = Base.decode16(id, case: :mixed)
    %BSON.ObjectId{value: bin}
  end

  @spec is_valid_id?(any) :: Boolean.t()
  def is_valid_id?(%BSON.ObjectId{} = id),
    do: Regex.match?(@bson_value_format, BSON.ObjectId.encode!(id))

  @spec max_in_collection(String.t(), atom) :: Int.t()
  def max_in_collection(collection, field) do
    Mongo.find(
      __MODULE__,
      collection,
      %{},
      sort: %{field => -1},
      limit: 1
    )
    |> Enum.to_list()
    |> calculate_max(Atom.to_string(field))
  end

  @spec content_of(String.t(), Map.t(), Map.t()) :: List.t()
  def content_of(collection, filter, sort) do
    Mongo.find(__MODULE__, collection, filter, sort: sort)
    |> Enum.to_list()
  end

  @spec drop_collections(List.t()) :: any
  def drop_collections(collections) do
    collections
    |> Enum.each(fn c ->
      Mongo.command(__MODULE__, %{:drop => c}, pool: DBConnection.Poolboy)
    end)
  end

  @spec sort_expression() :: any
  def sort_expression(), do: %{counter: 1}

  @spec type_expression([String.t()]) :: any
  def type_expression(types), do: %{type: %{"$in" => types}}

  @spec correlation_id_expression(String.t()) :: any
  def correlation_id_expression(correlation_id), do: %{correlation_id: correlation_id}

  @spec calculate_max(List.t(), String.t()) :: Int.t()
  defp calculate_max([], _field), do: 0
  defp calculate_max([e], field), do: e[field]
end
