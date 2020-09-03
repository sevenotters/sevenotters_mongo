defmodule SevenottersMongo.Storage do
  @moduledoc false

  require Logger
#  @behaviour Seven.Data.PersistenceBehaviour

  @bson_value_format ~r/^[A-Fa-f0-9\-]{24}$/
  @pool_size 10

  @events "events"
  @snapshots "snapshots"
  @processes "processes"

  def start_link(opts \\ []) do
    Mongo.start_link(opts ++ [name: __MODULE__, pool_size: @pool_size])
  end

  @spec initialize() :: any
  def initialize(), do: nil

  @spec insert_event(map) :: any
  def insert_event(value) do
    {:ok, _id} = Mongo.insert_one(__MODULE__, @events, value)
  end

  @spec upsert_snapshot(bitstring, map) :: any
  def upsert_snapshot(correlation_id, value) do
    filter = %{correlation_id: correlation_id}
    {:ok, _id} = Mongo.update_one(__MODULE__, @snapshots, filter, %{"$set": value}, upsert: true)
  end

  @spec upsert_process(bitstring, map) :: any
  def upsert_process(process_id, value) do
    filter = %{process_id: process_id}
    {:ok, _id} = Mongo.update_one(__MODULE__, @processes, filter, %{"$set": value}, upsert: true)
  end

  @spec get_snapshot(bitstring) :: map | nil
  def get_snapshot(correlation_id) do
    Mongo.find_one(__MODULE__, @snapshots, %{correlation_id: correlation_id})
    |> atomize()
  end

  @spec get_process(bitstring) :: map | nil
  def get_process(process_id) do
    Mongo.find_one(__MODULE__, @processes, %{process_id: process_id})
    |> atomize()
  end

  defp atomize(nil), do: nil
  defp atomize(entities) when is_list(entities), do: entities |> Enum.map(fn s -> AtomicMap.convert(s, safe: false) end)
  defp atomize(entity), do: AtomicMap.convert(entity, safe: false)

  @spec new_id :: any
  def new_id, do: Mongo.object_id()

  @spec new_printable_id :: bitstring
  def new_printable_id, do: Mongo.object_id() |> BSON.ObjectId.encode!()

  @spec printable_id(any) :: bitstring
  def printable_id(%BSON.ObjectId{} = id), do: BSON.ObjectId.encode!(id)
  def printable_id(id) when is_bitstring(id), do: id

  @spec object_id(bitstring) :: any
  def object_id(id) do
    {_, bin} = Base.decode16(id, case: :mixed)
    %BSON.ObjectId{value: bin}
  end

  @spec is_valid_id?(any) :: boolean
  def is_valid_id?(%BSON.ObjectId{} = id),
    do: Regex.match?(@bson_value_format, BSON.ObjectId.encode!(id))

  @spec max_counter_in_events() :: integer
  def max_counter_in_events() do
    Mongo.find(
      __MODULE__,
      @events,
      %{},
      sort: %{:counter => -1},
      limit: 1
    )
    |> Enum.to_list()
    |> calculate_max(Atom.to_string(:counter))
  end

  @spec events() :: [map]
  def events() do
    Mongo.find(__MODULE__, @events, %{}, sort: %{}) # TODO: streaming with cursor?
    |> Enum.to_list()
  end

  @spec snapshots() :: [map]
  def snapshots() do
    Mongo.find(__MODULE__, @snapshots, %{}, sort: %{}) # TODO: streaming with cursor?
    |> Enum.to_list()
    |> atomize()
  end

  @spec processes() :: [map]
  def processes() do
    Mongo.find(__MODULE__, @processes, %{}, sort: %{}) # TODO: streaming with cursor?
    |> Enum.to_list()
    |> atomize()
  end

  @spec events_by_correlation_id(bitstring, integer) :: [map]
  def events_by_correlation_id(correlation_id, after_counter) do
    Mongo.find(__MODULE__, @events, %{correlation_id: correlation_id, counter: %{"$gt" => after_counter}}, sort: %{counter: 1})
    |> Enum.to_list()
  end

  @spec event_by_id(bitstring) :: map
  def event_by_id(id) do
    Mongo.find_one(__MODULE__, @events, %{id: id}) |> atomize()
  end

  @spec events_by_types([bitstring], integer) :: [map]
  def events_by_types(types, after_counter) do
    Mongo.find(__MODULE__, @events, %{type: %{"$in" => types}, counter: %{"$gt" => after_counter}}, sort: %{counter: 1})
    |> Enum.to_list()
  end

  @spec drop_events() :: any
  def drop_events() do
    Mongo.command(__MODULE__, %{:drop => @events}, pool: DBConnection.Poolboy)
  end

  @spec drop_snapshots() :: any
  def drop_snapshots() do
    Mongo.command(__MODULE__, %{:drop => @snapshots}, pool: DBConnection.Poolboy)
  end

  @spec drop_processes() :: any
  def drop_processes() do
    Mongo.command(__MODULE__, %{:drop => @processes}, pool: DBConnection.Poolboy)
  end

  @callback processes_id_by_status(bitstring) :: [map]
  def processes_id_by_status(status) do
    Mongo.find(__MODULE__, @processes, %{status: status}, projection: %{process_id: 1})
    |> Enum.to_list()
    |> Enum.map(fn p -> p["process_id"] end)
  end

  #
  # Privates
  #
  @spec calculate_max([map], bitstring) :: integer
  defp calculate_max([], _field), do: 0
  defp calculate_max([e], field), do: e[field]
end
