defmodule Xod.Optional do
  @type t() :: %__MODULE__{schema: Xod.Schema.t()}

  @enforce_keys [:schema]
  defstruct [:schema]

  @spec new(Xod.Schema.t()) :: t()
  def new(schema) when is_struct(schema) do
    %__MODULE__{schema: schema}
  end

  defimpl Xod.Schema do
    alias Xod, as: X

    @impl true
    def parse(%Xod.Optional{schema: schema}, value, path) do
      case value do
        nil ->
          raise ArgumentError, "Xod.Optional called on nil"

        other ->
          X.Schema.parse(schema, other, path)
      end
    end
  end
end
