defmodule Mix.Tasks.Degenerator do
  @moduledoc """
  Create a generator from an existing module.

  """

  use Mix.Task

  alias Degenerator.Inflection

  @requirements ["app.config"]
  @mix_task_path "lib/mix/tasks"

  def run(args) do
    case OptionParser.parse(args, switches: [module: :string, project_root: :string, app: :string]) do
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
      mix degenerator --module MyProject.MyModule

    """)
  end

  def build_context_from_opts(opts) do
    project_root = Keyword.get(opts, :project_root, File.cwd!())

    module = opts |> Keyword.fetch!(:module) |> Inflection.new()
    project = base() |> Inflection.new()

    generator = select_generator(project, module)

    template_path = String.replace(module.path, to_string(module.base), "my_project")
    templates_root = template_path(generator)

    target = Path.join(templates_root, template_path)

    app = Mix.Project.config() |> Keyword.fetch!(:app)

    %{
      module: module,
      project: project,
      project_root: project_root,
      template_path: template_path,
      templates_root: templates_root,
      generator: generator,
      target: target,
      app: app,
      original_options: opts
    }
  end

  def prewalk({:moduledoc, moduledoc_meta, moduledoc}, acc) do
    # TODO add generator info to moduledoc
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
    module_alias = acc.module.alias

    new_aliases =
      aliases
      |> Enum.map(fn
        ^module_base -> :"<%= project %>"
        ^module_alias -> :"<%= module_name %>"
        section -> section
      end)

    {{:__aliases__, aliases_meta, new_aliases}, acc}
  end

  def postwalk(quoted, acc) do
    {quoted, acc}
  end

  def generator_postwalk(
        {:@, _, [{:module_templates, _, [{:__block__, _, _}]}]} = quoted,
        context
      ) do
    # TODO: There is a real refactor opertunity for this function

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
          # TODO: We can look for and replace duplicates by evaluating the AST
          #   {templates, _biding} = Code.eval_quoted(templates_path_block)
          #   and navigating that AST

          # TODO: This should be a component that is evaluated to stop duplication between here and the template
          new_template =
            ~s(%{path: "#{context.template_path}", default_module_name: "#{context.module.alias}", lowercase: "#{context.module.lowercase}"})

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
    "priv/templates/#{generator.lowercase}"
  end

  def base, do: Mix.Phoenix.base()

  def write_generator_module(context) when not context.generator.existing? do
    files = [{:eex, "generator.ex", context.generator.path}]
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
    # acc = [moduledoc: "This file was generated by running `command`", auxiliary_modules: []]

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

    Mix.Generator.create_file(context.target, source)

    context
  end

  def print_shell_results(context) do
    Mix.shell().info("""

    You can run this generator with:

      > mix #{context.generator.lowercase}

    Or pass in options:

      > mix #{context.generator.lowercase} --project #{context.project.alias} --module #{context.module.alias}

    """)

    context
  end

  def select_generator(project, module) do
    default = Inflection.new("Mix.Tasks.#{project.base}.Gen.#{module.alias}")

    tasks =
      case File.ls(@mix_task_path) do
        {:ok, tasks} ->
          tasks
          |> Enum.map(&Path.join(@mix_task_path, &1))
          |> Enum.map(&String.trim_leading(&1, "lib/"))
          |> Enum.map(&String.trim_trailing(&1, ".ex"))
          |> Enum.map(&Inflection.new/1)
          |> List.insert_at(-1, default)
          |> Enum.uniq()
          |> Enum.sort(fn a, _b -> a.existing? end)

        {:error, :enoent} ->
          [default]
      end

    Enum.reduce_while(tasks, nil, &prompt_for_generator/2)
  end

  defp prompt_for_generator(task, acc) do
    prompt =
      case task do
        %{existing?: true} ->
          "#{IO.ANSI.green()}* #{IO.ANSI.reset()}Use exisitng generator task #{IO.ANSI.bright()}#{task.lowercase}#{IO.ANSI.reset()}?"

        %{existing?: false} ->
          "#{IO.ANSI.green()}* #{IO.ANSI.reset()}Create new generator task #{IO.ANSI.bright()}#{task.lowercase}#{IO.ANSI.reset()}?"
      end

    case Mix.shell().yes?(prompt) do
      true -> {:halt, task}
      false -> {:cont, acc}
    end
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
end
