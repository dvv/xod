defmodule Xod.Coercive do
  @type t() :: %__MODULE__{schema: Xod.Schema.t()}

  @enforce_keys [:schema]
  defstruct [:schema]

  @spec new(Xod.Schema.t()) :: t()
  def new(schema) when is_struct(schema) do
    %__MODULE__{schema: schema}
  end

  defimpl Xod.Schema do

    @impl true
    def parse(%Xod.Coercive{schema: %Xod.Number{int: true} = schema}, value, path) when is_binary(value) do
      value = case Integer.parse(value) do
        {value, ""} -> value
        _ -> value
      end
      Xod.Schema.parse(schema, value, path)
    end
    def parse(%Xod.Coercive{schema: %Xod.Number{} = schema}, value, path) when is_binary(value) do
      value = case Float.parse(value) do
        {value, ""} -> value
        _ -> value
      end
      Xod.Schema.parse(schema, value, path)
    end
    def parse(%Xod.Coercive{schema: %Xod.Boolean{} = schema}, value, path) do
      cond do
        value in ["true"] -> Xod.Schema.parse(schema, true, path)
        value in ["false"] -> Xod.Schema.parse(schema, false, path)
        true -> Xod.Schema.parse(schema, value, path)
      end
    end
    def parse(%Xod.Coercive{schema: %Xod.Literal{value: atom} = schema}, value, path) when is_atom(atom) and is_binary(value) do
      Xod.Schema.parse(schema, String.to_atom(value), path)
    end
    def parse(%Xod.Coercive{schema: %Xod.String{} = schema}, value, path) when not is_binary(value) do
      Xod.Schema.parse(schema, to_string(value), path)
    end
    def parse(%Xod.Coercive{schema: %Xod.List{} = schema}, value, path) when is_map(value) do
      Xod.Schema.parse(schema, Map.values(value), path)
    end
    def parse(%Xod.Coercive{schema: schema}, value, path) do
      Xod.Schema.parse(schema, value, path)
    end
  end
end

defmodule Xod.DateTime do
  @type t() :: %__MODULE__{coerce: boolean()}

  defstruct [:coerce]

  @spec new(coerce: boolean()) :: t()
  def new(opts \\ []), do: struct(__MODULE__, opts)

  defimpl Xod.Schema do

    @impl true
    def parse(_, value, _) when is_struct(value, DateTime), do: {:ok, value}
    def parse(%Xod.DateTime{coerce: true}, "now", _), do: {:ok, DateTime.now!("Etc/UTC")}
    def parse(%Xod.DateTime{coerce: true}, value, path) when is_binary(value) do
      case DateTime.from_iso8601(value) do
        {:ok, value, _} -> {:ok, value}
        {:error, _reason} -> {:error, Xod.XodError.invalid_type(:datetime, Xod.Common.get_type(value), path)}
      end
    end
    def parse(_, value, path), do: {:error, Xod.XodError.invalid_type(:datetime, Xod.Common.get_type(value), path)}
  end
end

defmodule Xod.Date do
  @type t() :: %__MODULE__{coerce: boolean()}

  defstruct [:coerce]

  @spec new(coerce: boolean()) :: t()
  def new(opts \\ []), do: struct(__MODULE__, opts)

  defimpl Xod.Schema do

    @impl true
    def parse(_, value, _) when is_struct(value, Date), do: {:ok, value}
    def parse(%Xod.Date{coerce: true}, value, path) when is_binary(value) do
      case Date.from_iso8601(value) do
        {:ok, value} -> {:ok, value}
        {:error, _reason} -> {:error, Xod.XodError.invalid_type(:date, Xod.Common.get_type(value), path)}
      end
    end
    def parse(_, value, path), do: {:error, Xod.XodError.invalid_type(:date, Xod.Common.get_type(value), path)}
  end
end

defmodule Xod.Time do
  @type t() :: %__MODULE__{coerce: boolean()}

  defstruct [:coerce]

  @spec new(coerce: boolean()) :: t()
  def new(opts \\ []), do: struct(__MODULE__, opts)

  defimpl Xod.Schema do

    @impl true
    def parse(_, value, _) when is_struct(value, Time), do: {:ok, value}
    def parse(%Xod.Time{coerce: true}, value, path) when is_binary(value) do
      case Time.from_iso8601(value) do
        {:ok, value} -> {:ok, value}
        {:error, _reason} -> {:error, Xod.XodError.invalid_type(:time, Xod.Common.get_type(value), path)}
      end
    end
    def parse(_, value, path), do: {:error, Xod.XodError.invalid_type(:time, Xod.Common.get_type(value), path)}
  end
end

defmodule Xod.Lazy do
  @type t() :: %__MODULE__{callee: {module(), atom(), [any()]} | {fun(), [any()]}}

  @enforce_keys [:callee]
  defstruct [:callee]

  @spec new(module(), atom(), [any()]) :: t()
  def new(m, f, a) when is_atom(m) and is_atom(f) and is_list(a) do
    %__MODULE__{callee: {m, f, a}}
  end

  @spec new(fun(), [any()]) :: t()
  def new(f, a) when is_function(f) and is_list(a) do
    %__MODULE__{callee: {f, a}}
  end

  defimpl Xod.Schema do
    @impl true
    def parse(%Xod.Lazy{callee: {m, f, a}}, value, path) do
      schema = Kernel.apply(m, f, a)
      Xod.Schema.parse(schema, value, path)
    end

    def parse(%Xod.Lazy{callee: {f, a}}, value, path) do
      schema = Kernel.apply(f, a)
      Xod.Schema.parse(schema, value, path)
    end
  end
end
