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
      existing?: false
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
      existing?: false
    }

    iex> Degenerator.Inflection.new(:factory, plural: :factories)
    %Degenerator.Inflection{
      singular: :factory,
      plural: :factories,
      id: :factory_id,
      camelized: :Factory,
      context: :Factories,
      base: :Degenerator,
      namespace: Degenerator,
      module: Degenerator.Factory,
      split: ["Degenerator", "Factory"],
      existing?: false
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

  def new(module, opts \\ [])

  def new("Elixir." <> module, opts) do
    split = ("Elixir." <> module) |> Module.split() |> List.delete("Elixir")
    namespace = namespace(split, opts)
    singular = singular(split, namespace)

    module = Module.concat(split)
    plural = Keyword.get_lazy(opts, :plural, fn -> :"#{singular}s" end)
    id = Keyword.get_lazy(opts, :id, fn -> :"#{singular}_id" end)
    camelized = camelize(singular)
    context = camelize(plural)
    base = base(opts)
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

  def new(module, opts) when is_binary(module) do
    case Keyword.fetch(opts, :namespace) do
      {:ok, namespace} ->
        new(Atom.to_string(namespace) <> "." <> Atom.to_string(camelize(module)), opts)

      :error ->
        new(
          "Elixir." <> Atom.to_string(base(opts)) <> "." <> Atom.to_string(camelize(module)),
          opts
        )
    end
  end

  def new(module, opts) when is_atom(module), do: new(Atom.to_string(module), opts)

  # :healthcare_service -> HealthcareService
  def camelize(singular) do
    singular
    |> to_string()
    |> String.split(".")
    |> Enum.map(&Macro.camelize/1)
    |> Enum.join(".")
    |> String.to_atom()
  end

  defp namespace(module_split, opts) do
    default =
      module_split
      |> case do
        [_] -> module_split
        [_ | _] -> List.delete_at(module_split, -1)
      end
      |> Module.concat()

    Keyword.get(opts, :namespace, default)
  end

  defp singular(module_split, namespace) do
    module_split
    |> strip_namespace(Module.split(namespace))
    |> Enum.map(&Macro.underscore/1)
    |> Enum.join(".")
    |> String.to_atom()
  end

  defp strip_namespace(module_split, []), do: module_split

  defp strip_namespace([h], [h]), do: [h]

  defp strip_namespace([h | module_split], [h | namespace_split]),
    do: strip_namespace(module_split, namespace_split)

  defp strip_namespace(module_split, _), do: [List.last(module_split)]

  defp path(module) do
    case Code.ensure_loaded?(module) do
      true -> module.__info__(:compile) |> Keyword.fetch!(:source) |> Path.relative_to_cwd()
      false -> nil
    end
  end

  defp base(opts) do
    case Keyword.fetch(opts, :base) do
      {:ok, base} -> camelize(base)
      :error -> Mix.Project.config() |> Keyword.fetch!(:app) |> camelize()
    end
  end
end
