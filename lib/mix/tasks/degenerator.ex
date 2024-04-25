defmodule Mix.Tasks.Degenerator do
  @moduledoc """
  Create a generator for a subject from an existing module. Or add to an existing subject generator from an existing module.
  """

  use Mix.Task

  alias Degenerator.Inflection

  @requirements ["app.config"]
  @mix_task_path "lib/mix/tasks"

  def run(args) do
    case OptionParser.parse(args,
           switches: [variable: :string, sgenerator: :string, module: :string, app: :string]
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

    template_map = build_template_map(module, subject)

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

  def generator_postwalk(
        {:@, _, [{:templates, _, [{:__block__, _, _}]}]} = quoted,
        context
      ) do
    updated_quoted =
      update_in(
        quoted,
        [
          Access.elem(2),
          Access.at(0),
          Access.elem(2),
          Access.at(0),
          Access.elem(2),
          Access.at(0)
        ],
        fn templates_path_block ->
          # FUture: We can look for and replace duplicates by evaluating the AST
          #   {templates, _biding} = Code.eval_quoted(templates_path_block)
          #   and navigating that AST

          new_template = context.module |> build_template_map(context.subject) |> inspect()
          new_quoted_template = Code.string_to_quoted!(new_template, to_quoted_opts())

          templates_path_block ++ [new_quoted_template]
        end
      )

    {updated_quoted, context}
  end

  def generator_postwalk(quoted, acc) do
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
    {forms, comments} =
      context.generator.path
      |> File.read!()
      |> Code.string_to_quoted_with_comments!(to_quoted_opts())

    {forms, context} =
      Macro.postwalk(
        forms,
        context,
        &generator_postwalk/2
      )

    to_algebra_opts = [comments: comments]
    doc = Code.Formatter.to_algebra(forms, to_algebra_opts)
    source = Inspect.Algebra.format(doc, 98) |> Enum.join()

    Mix.Generator.create_file(context.generator.path, source)

    context
  end

  def write_module_template(context) do
    {forms, comments} =
      context.module.path
      |> File.read!()
      |> Code.string_to_quoted_with_comments!(to_quoted_opts())

    {forms, context} =
      Macro.traverse(
        forms,
        context,
        &prewalk/2,
        &postwalk/2
      )

    to_algebra_opts = [comments: comments]
    doc = Code.Formatter.to_algebra(forms, to_algebra_opts)
    source = Inspect.Algebra.format(doc, 98) |> Enum.join()

    target_path =
      template_path(context.generator) <>
        "/" <> build_template_source_path(context.module, context.subject)

    Mix.Generator.create_file(target_path, source)

    context
  end

  def print_shell_results(context) do
    Mix.shell().info("""

    You can run this generator with:

      > mix #{context.generator.singular} --#{context.subject} #{context.subject}

    """)

    context
  end

  defp generator_roots, do: [".", :degenerator]

  def to_quoted_opts(opts \\ []) do
    [
      unescape: false,
      warn_on_unnecessary_quotes: false,
      literal_encoder: &{:ok, {:__block__, &2, [&1]}},
      token_metadata: true,
      warnings: false
    ] ++ opts
  end

  defp build_template_map(module, subject) do
    source = build_template_source_path(module, subject)

    dest =
      module.path
      |> String.replace(to_string(module.plural), "<%= plural %>")
      |> String.replace(to_string(module.singular), "<%= singular %>")

    namespace =
      module.namespace
      |> to_string()
      |> String.replace(to_string(module.base), "<%= base %>")

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
