defmodule Xod.Map do
  alias Xod, as: X
  require X.Common

  @type foreign_keys() :: :strip | :strict | :passthrough | X.Schema.t()

  @type t() :: %__MODULE__{
          keyval: %{optional(term()) => X.Schema.t()},
          foreign_keys: foreign_keys(),
          coerce: boolean(),
          key_coerce: boolean(),
          map_keys: map(),
          struct: module() | struct(),
          min: non_neg_integer(),
          max: non_neg_integer(),
          length: non_neg_integer()
        }

  @enforce_keys [:keyval]
  defstruct [:keyval, :struct, :min, :max, :length, foreign_keys: :strip, coerce: true, key_coerce: false, map_keys: %{}]

  @spec new(%{optional(term()) => X.Schema.t()},
          foreign_keys: foreign_keys(),
          coerce: boolean(),
          key_coerce: boolean(),
          map_keys: map(),
          struct: module() | struct(),
          min: non_neg_integer(),
          max: non_neg_integer(),
          length: non_neg_integer()
        ) ::
          %__MODULE__{}
  def new(map, opts \\ []) when is_map(map) do
    struct(%__MODULE__{keyval: map}, opts)
  end

  @spec shape(t()) :: %{optional(term()) => X.Schema.t()}
  def shape(schema), do: schema.keyval

  @spec check_all(t(), X.Schema.t()) :: t()
  def check_all(schema, check), do: Map.put(schema, :foreign_keys, check)

  defimpl Xod.Schema do
    alias Xod, as: X

    defp from_list(l) do
      Enum.into(X.Common.kv_from_list(l), %{})
    end

    defp has_key?(m, a) do
      Map.has_key?(m, a) or Map.has_key?(m, to_string(a))
    end

    defp get_key(m, a) do
      Map.get(m, a, Map.get(m, to_string(a)))
    end

    defp del_key(m, a) do
      Map.drop(m, [a, to_string(a)])
    end

    @impl true
    def parse(%X.Map{coerce: false}, list, path) when is_list(list) do
      {:error, X.XodError.invalid_type(:map, :list, path)}
    end

    @impl true
    def parse(_, not_a_map, path) when not is_map(not_a_map) and not is_list(not_a_map) do
      {:error, X.XodError.invalid_type(:map, X.Common.get_type(not_a_map), path)}
    end

    @impl true
    def parse(schema, map, path) do
      map = if(is_list(map), do: from_list(map), else: map)
      has? = if(schema.key_coerce, do: &has_key?/2, else: &Map.has_key?/2)
      get = if(schema.key_coerce, do: &get_key/2, else: &Map.get/2)
      drop = if(schema.key_coerce, do: &del_key/2, else: &Map.drop(&1, [&2]))

      map_keys = schema.map_keys
      {parsed, mapLeft, errors} =
        Enum.reduce(
          schema.keyval,
          {%{}, map, []},
          fn {key, schema}, {parsed, mapLeft, errors} ->
            skey = Map.get(map_keys, key, key)
            value = get.(mapLeft, skey)
            res = case schema do
              %Xod.Optional{schema: schema} ->
                case has?.(mapLeft, skey) do
                  true -> X.Schema.parse(schema, value, List.insert_at(path, -1, key))
                  false -> :skip
                end
              _ -> X.Schema.parse(schema, value, List.insert_at(path, -1, key))
            end

            case res do
              {:error, err} ->
                {parsed, drop.(mapLeft, skey), List.insert_at(errors, -1, err)}

              {:ok, val} ->
                {Map.put(parsed, key, val), drop.(mapLeft, skey), errors}

              :skip ->
                {parsed, mapLeft, errors}
            end
          end
        )

      {extraParsed, _, extraErrors} =
        if is_struct(schema.foreign_keys) do
          Enum.reduce(
            mapLeft,
            {%{}, map, []},
            fn {key, value}, {parsed, mapLeft, errors} ->
              res = X.Schema.parse(schema.foreign_keys, value, List.insert_at(path, -1, key))

              case res do
                {:error, err} ->
                  {parsed, drop.(mapLeft, key), List.insert_at(errors, -1, err)}

                {:ok, val} ->
                  {Map.put(parsed, key, val), drop.(mapLeft, key), errors}
              end
            end
          )
        else
          {%{}, nil, []}
        end

      parsed = Map.merge(parsed, extraParsed)
      #  |> Enum.map(fn {k, v} -> {schema.map_keys[k] || k, v} end)
      #  |> Enum.into(%{})
      errors = errors ++ extraErrors

      parsed =
        unless(is_nil(schema.struct),
          do: struct(schema.struct, parsed),
          else: parsed
        )

      result = case {errors, schema.foreign_keys} do
        {[], :passthrough} ->
          {:ok, Map.merge(parsed, mapLeft)}

        {[], :strict} ->
          case mapLeft do
            left when map_size(left) == 0 ->
              {:ok, parsed}

            left ->
              {:error,
               %X.XodError{
                 issues: [
                   [
                     type: :unrecognized_keys,
                     path: path,
                     data: [keys: Map.keys(left)],
                     message:
                       "Unrecognized key(s) in map: #{Enum.map_join(Map.keys(left), ", ", &inspect(&1))}"
                   ]
                 ]
               }}
          end

        {[], k} when k == :strip or is_struct(k) ->
          {:ok, parsed}

        {errors, _} ->
          {:error, %X.XodError{issues: Enum.map(errors, & &1.issues) |> :lists.append()}}
      end

      case result do
        {:ok, parsed} ->
          length_errors =
            [
              schema.max && map_size(parsed) > schema.max &&
                [
                  type: :too_big,
                  path: path,
                  message: "Map must contain at most #{schema.max} key(s)",
                  data: [
                    max: schema.max
                  ]
                ],
              schema.min && map_size(parsed) < schema.min &&
                [
                  type: :too_small,
                  path: path,
                  message: "Map must contain at least #{schema.min} key(s)",
                  data: [
                    min: schema.min
                  ]
                ],
              schema.length && map_size(parsed) !== schema.length &&
                [
                  type: if(map_size(parsed) < schema.length, do: :too_small, else: :too_big),
                  path: path,
                  message: "Map must contain exactly #{schema.length} key(s)",
                  data: [
                    equal: schema.length
                  ]
                ]
            ]
            |> Enum.filter(&Function.identity/1)
          if length(length_errors) > 0 do
            {:error, %X.XodError{issues: length_errors}}
          else
            {:ok, parsed}
          end
        {:error, error} -> {:error, error}
      end
    end
  end
end
