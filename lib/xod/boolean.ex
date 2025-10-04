defmodule Xod.Boolean do
  @type t() :: %__MODULE__{coerce: boolean()}

  defstruct [coerce: true]

  @spec new(coerce: boolean()) :: t()
  def new(opts \\ []), do: struct(__MODULE__, opts)

  defimpl Xod.Schema do

    def parse(%Xod.Boolean{coerce: true} = schema, value, path) when is_binary(value) do
      cond do
        value in ["true"] -> Xod.Schema.parse(%{schema | coerce: false}, true, path)
        value in ["false"] -> Xod.Schema.parse(%{schema | coerce: false}, false, path)
        true -> Xod.Schema.parse(%{schema | coerce: false}, value, path)
      end
    end

    @impl true
    def parse(%Xod.Boolean{coerce: false}, value, path) when not is_boolean(value) do
      {:error, Xod.XodError.invalid_type(:boolean, Xod.Common.get_type(value), path)}
    end

    @impl true
    def parse(_, value, _) do
      if value, do: {:ok, true}, else: {:ok, false}
    end
  end
end
