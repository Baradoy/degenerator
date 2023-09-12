defmodule Degenerator.Inflection do
  @moduledoc """
    Holds different representations of the same module.

    ## Examples

      Inflection.new(Degenerator.Inflection)
      #=> %Degenerator.Inflection{
        alias: :Inflection,
        base: Elixir,
        existing?: true,
        lowercase: "inflection",
        module: Degenerator.Inflection,
        path: "/Users/baradoy/Code/degenerator/lib/degenerator/inflection.ex"
      }

  """

  @type t() :: %__MODULE__{
          alias: atom(),
          base: atom(),
          existing?: boolean(),
          lowercase: String.t(),
          module: atom(),
          path: String.t()
        }

  defstruct [:alias, :base, :existing?, :lowercase, :module, :path]

  @doc "Create an inflection from a module"
  @spec new(atom() | String.t()) :: t()
  def new(module) when is_atom(module),
    do: module |> Atom.to_string() |> new()

  def new(module_string) when is_binary(module_string) do
    %__MODULE__{}
    |> build_module_components(module_string)
    |> check_existing()
    |> build_lowercase()
    |> build_path()
  end

  defp build_module_components(inflection, module_string) do
    {module, base, alias} = module_string |> module_components() |> decompose_components()

    %{inflection | module: module, base: base, alias: alias}
  end

  defp check_existing(inflection) do
    %{inflection | existing?: Code.ensure_loaded?(inflection.module)}
  end

  defp build_lowercase(inflection) do
    lowercase =
      inflection.alias
      |> Atom.to_string()
      |> String.trim_leading("Elixir.")
      |> String.split(".")
      |> Enum.map(&Macro.underscore/1)
      |> Enum.join(".")

    %{inflection | lowercase: lowercase}
  end

  defp build_path(inflection) when inflection.existing? do
    path =
      inflection.module.__info__(:compile) |> Keyword.fetch!(:source) |> Path.relative_to_cwd()

    %{inflection | path: path}
  end

  defp build_path(inflection) when not inflection.existing? do
    path_base =
      inflection.base
      |> Atom.to_string()
      |> String.trim_leading("Elixir.")
      |> Macro.underscore()

    path = Path.join(["lib", path_base, inflection.lowercase <> ".ex"])

    %{inflection | path: path}
  end

  defp module_components(module) do
    module
    |> Macro.camelize()
    |> String.split(".")
    |> Enum.map(&Macro.camelize/1)
    |> Enum.map(&String.to_atom/1)
  end

  defp decompose_components([:Mix, :Tasks | alias] = components),
    do: {Module.concat(components), Mix.Tasks, alias |> Enum.join(".") |> String.to_atom()}

  defp decompose_components(components),
    do: {Module.concat(components), List.first(components), List.last(components)}
end
