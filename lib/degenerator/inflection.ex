defmodule Degenerator.Inflection do
  @moduledoc """
  Provides inflection for an atom. Usefull for metaprogramming and whatnot.

  ## Examples

    iex> Degenerator.Inflection.new(:patient, namespace: Degenerator.Schema)
    %Degenerator.Inflection{
      singular: :patient,
      plural: :patients,
      id: :patient_id,
      camelized: :Patient,
      context: :Patients,
      base: :Degenerator,
      namespace: Degenerator.Schema,
      module: Degenerator.Schema.Patient,
      split: ["Degenerator", "Schema", "Patient"],
      existing?: false,
      path: nil
    }

    iex> Degenerator.Inflection.new(Degenerator.Schema.AuditEvent)
    %Degenerator.Inflection{
      singular: :audit_event,
      plural: :audit_events,
      id: :audit_event_id,
      camelized: :AuditEvent,
      context: :AuditEvents,
      base: :Degenerator,
      namespace: Degenerator.Schema,
      module: Degenerator.Schema.AuditEvent,
      split: ["Degenerator", "Schema", "AuditEvent"],
      existing?: false,
      path: nil
    }

    iex> Degenerator.Inflection.new(:factory, plural: :factories)
    %Degenerator.Inflection{
      singular: :factory,
      plural: :factories,
      id: :factory_id,
      camelized: :Factory,
      context: :Factories,
      base: :Degenerator,
      namespace: :Degenerator,
      module: Degenerator.Factory,
      split: ["Degenerator", "Factory"],
      existing?: false,
      path: nil
    }

    iex> Degenerator.Inflection.new(:inflection)
    %Degenerator.Inflection{
      singular: :inflection,
      plural: :inflections,
      id: :inflection_id,
      camelized: :Inflection,
      context: :Inflections,
      base: :Degenerator,
      namespace: :Degenerator,
      module: Degenerator.Inflection,
      split: ["Degenerator", "Inflection"],
      existing?: true,
      path: "lib/degenerator/inflection.ex"
    }

    iex> Degenerator.Inflection.new("Degenerator.Inflection")
    %Degenerator.Inflection{
      singular: :inflection,
      plural: :inflections,
      id: :inflection_id,
      camelized: :Inflection,
      context: :Inflections,
      base: :Degenerator,
      namespace: :Degenerator,
      module: Degenerator.Inflection,
      split: ["Degenerator", "Inflection"],
      existing?: true,
      path: "lib/degenerator/inflection.ex"
    }

    iex> Degenerator.Inflection.new(:Degenerator)
    %Degenerator.Inflection{
      singular: :degenerator,
      plural: :degenerators,
      id: :degenerator_id,
      camelized: :Degenerator,
      context: :Degenerators,
      base: :Degenerator,
      namespace: :Degenerator,
      module: Degenerator.Degenerator,
      split: ["Degenerator", "Degenerator"],
      existing?: false,
      path: nil
    }
  """

  defstruct [
    :singular,
    :plural,
    :id,
    :camelized,
    :context,
    :base,
    :namespace,
    :module,
    :split,
    :path,
    :existing?
  ]

  defguard is_inflection(inflection) when is_struct(inflection, __MODULE__)

  def new(module, opts \\ [])

  def new(module, opts) when is_binary(module) do
    {singular, base, namespace} = build_singular(module, opts)

    plural = Keyword.get_lazy(opts, :plural, fn -> :"#{singular}s" end)
    camelized = camelize(singular)
    context = camelize(plural)

    split =
      (namespace |> to_common_string() |> String.split(".")) ++
        (camelized |> to_common_string() |> String.split("."))

    module = Module.concat(split)
    id = Keyword.get_lazy(opts, :id, fn -> :"#{singular}_id" end)
    path = path(module)
    existing = Code.ensure_loaded?(module)

    %__MODULE__{
      singular: singular,
      plural: plural,
      id: id,
      camelized: camelized,
      context: context,
      base: base,
      namespace: namespace,
      module: module,
      split: split,
      path: path,
      existing?: existing
    }
  end

  def new(module, opts) when is_atom(module), do: new(Atom.to_string(module), opts)

  # :healthcare_service -> HealthcareService
  def camelize(value) when is_atom(value), do: value |> to_string() |> camelize()

  def camelize(value) when is_binary(value), do: value |> String.split(".") |> camelize()

  def camelize(value) when is_list(value) do
    value
    |> Enum.map_join(".", &Macro.camelize/1)
    |> String.to_atom()
  end

  defp path(module) do
    case Code.ensure_loaded?(module) do
      true -> module.__info__(:compile) |> Keyword.fetch!(:source) |> Path.relative_to_cwd()
      false -> nil
    end
  end

  defp base(module, opts) do
    module_split = module |> to_string() |> String.trim_leading("Elixir.") |> String.split(".")

    default =
      case module_split do
        [_] -> Mix.Project.config() |> Keyword.fetch!(:app) |> camelize()
        [base | _] -> camelize(base)
      end

    Keyword.get(opts, :base, default)
  end

  defp namespace(module, base, opts) do
    module_split = module |> to_string() |> String.split(".")

    default =
      case module_split do
        [_] -> base
        [_ | _] -> module_split |> List.delete_at(-1) |> camelize()
      end

    Keyword.get(opts, :namespace, default)
  end

  defp build_singular(name, opts) when is_atom(name),
    do: name |> Atom.to_string() |> String.trim_leading("Elixir.") |> build_singular(opts)

  defp build_singular(module, opts) when is_binary(module) do
    base = base(module, opts)
    namespace = namespace(module, base, opts)

    singular =
      module
      |> String.trim_leading("Elixir.")
      |> String.trim_leading(to_common_string(namespace) <> ".")
      |> String.split(".")
      |> Enum.map_join(".", &Macro.underscore/1)
      |> String.to_atom()

    {singular, base, namespace}
  end

  defp to_common_string(value), do: value |> to_string() |> String.trim_leading("Elixir.")
end
