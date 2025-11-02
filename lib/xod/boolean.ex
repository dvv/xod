defmodule Xod.Boolean do
  @type t() :: %__MODULE__{coerce: boolean()}

  defstruct [coerce: true]

  @spec new(coerce: boolean()) :: t()
  def new(opts \\ []), do: struct(__MODULE__, opts)

  defimpl Xod.Schema do

    @impl true
    def parse(%Xod.Boolean{coerce: true} = schema, value, path) when is_binary(value) do
      value = cond do
        value in ["true", "1"] -> true
        value in ["false", "0"] -> false
        true -> value
      end
      Xod.Schema.parse(%{schema | coerce: false}, value, path)
    end

    def parse(_, value, _) when is_boolean(value) do
      {:ok, value}
    end

    def parse(_, value, path) do
      {:error, Xod.XodError.invalid_type(:boolean, Xod.Common.get_type(value), path)}
    end
  end
end
