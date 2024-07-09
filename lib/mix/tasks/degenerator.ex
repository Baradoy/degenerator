defmodule Mix.Tasks.Degenerator do
  @moduledoc """
  Create a generator for a subject from an existing module. Or add to an existing subject generator from an existing module.
  """

  use Mix.Task

  import Degenerator.Inflection, only: [is_inflection: 1]

  alias Degenerator.Code
  alias Degenerator.Inflection

  @requirements ["app.config"]
  @mix_task_path "lib/mix/tasks"

  def run(args) do
    case OptionParser.parse(args,
           switches: [generator: :string, module: :string, app: :string]
         ) do
      {opts, [], []} -> create_generator(opts)
      _ -> usage()
    end
  end

  def create_generator(opts) do
    opts
    |> build_context_from_opts()
    |> write_generator_module()
    |> write_module_template()
    |> print_shell_results()
  end

  defp usage do
    Mix.shell().info("""
    Basic Usage:
      mix degenerator --module MyProject.MyModule --generator degenerator.gen.my_generator

    """)
  end

  def build_context_from_opts(opts) do
    module = opts |> Keyword.fetch!(:module) |> Inflection.new()
    project = base() |> String.to_atom() |> Inflection.new()
    subject = Keyword.get(opts, :subject, "subject")
    generator = build_context_generator(opts)

    template_map = module |> build_template_map(subject)

    template_path = String.replace(module.path, to_string(module.base), "my_project")
    templates_root = template_path(generator)

    %{
      module: module,
      project: project,
      subject: subject,
      template_map: template_map,
      template_path: template_path,
      templates_root: templates_root,
      generator: generator
    }
  end

  defp build_context_generator(opts) do
    opts
    |> Keyword.fetch!(:generator)
    |> Inflection.camelize()
    |> then(&Module.concat(Mix.Tasks, &1))
    |> Inflection.new(namespace: Mix.Tasks)
    |> then(&Map.put(&1, :path, "#{@mix_task_path}/#{&1.singular}.ex"))
  end

  def prewalk({:moduledoc, moduledoc_meta, moduledoc}, acc) do
    {{:moduledoc, moduledoc_meta, moduledoc}, acc}
  end

  def prewalk({:__aliases__, aliases_meta, aliases}, acc) do
    acc_aliases = Map.get(acc, :aliases, [List.first(aliases)])

    acc_aliases =
      if List.first(aliases) in acc_aliases do
        [List.last(aliases) | acc_aliases]
      else
        acc_aliases
      end

    new_acc = Map.put(acc, :aliases, acc_aliases)

    {{:__aliases__, aliases_meta, aliases}, new_acc}
  end

  def prewalk(quoted, acc) do
    {quoted, acc}
  end

  def postwalk({:__aliases__, aliases_meta, aliases}, acc) do
    # Replace the base name and the module name
    module_base = acc.module.base
    module_alias = acc.module.camelized

    new_aliases =
      aliases
      |> Enum.map(fn
        ^module_base -> :"<%= subject.base %>"
        ^module_alias -> :"<%= subject.camelized %>"
        section -> section
      end)

    {{:__aliases__, aliases_meta, new_aliases}, acc}
  end

  def postwalk(quoted, acc) do
    {quoted, acc}
  end

  def template_path(generator) do
    "priv/templates/#{generator.singular}"
  end

  def base, do: Mix.Project.config() |> Keyword.fetch!(:app) |> to_string() |> Macro.camelize()

  def write_generator_module(context) when not context.generator.existing? do
    files = [{:eex, "generator.ex.eex", context.generator.path}]
    binding = context |> Keyword.new()

    Mix.Phoenix.copy_from(generator_roots(), "priv/templates/degenerator", binding, files)

    context
  end

  def write_generator_module(context) when context.generator.existing? do
    source = context.generator.path
    target = context.generator.path
    new_template = context.module |> build_template_map(context.subject) |> inspect()

    Code.write_after_traversal(
      source,
      target,
      context,
      postwalk: Code.Quoted.module_attribute_append(new_template, :templates)
    )
  end

  def write_module_template(context) do
    source = context.module.path

    target =
      template_path(context.generator) <>
        "/" <> build_template_source_path(context.module, context.subject)

    Code.write_after_traversal(source, target, context,
      prewalk: &prewalk/2,
      postwalk: &postwalk/2
    )
  end

  def print_shell_results(context) do
    Mix.shell().info("""

    You can run this generator with:

      > mix #{context.generator.singular} --#{context.subject} #{context.subject}

    """)

    context
  end

  defp generator_roots, do: [".", :degenerator]

  defp build_template_map(module, subject) when is_inflection(module) do
    source = build_template_source_path(module, subject)

    dest =
      module.path
      |> String.replace(to_string(module.plural), "<%= plural %>")
      |> String.replace(to_string(module.singular), "<%= singular %>")

    namespace =
      module.namespace
      |> to_string()
      |> String.replace(to_string(module.base), "<%= base_underscore %>")

    %{
      source: source,
      dest: dest,
      subject: subject,
      namespace: namespace
    }
  end

  defp build_template_source_path(module, subject),
    do: String.replace(module.path, to_string(module.singular), subject) <> ".eex"
end
