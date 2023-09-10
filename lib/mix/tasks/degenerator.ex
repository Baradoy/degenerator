defmodule Mix.Tasks.Degenerator do
  @moduledoc """
  Create a generator from an existing module.

  """

  use Mix.Task

  @requirements ["app.config"]

  @defaults [
    generator: "generator"
  ]

  def run(args) do
    case OptionParser.parse(args, switches: [name: :string, path: :string, project_root: :string]) do
      {opts, [], []} -> create_generator(opts ++ @defaults)
      _ -> usage()
    end
  end

  def create_generator(opts) do
    opts
    |> build_context_from_opts()
    |> write_module_template()
    |> write_generator_module()
    |> print_shell_results()
  end

  defp usage do
    Mix.shell().info("""
    Usage: mix degenerator path
    """)
  end

  def build_context_from_opts(opts) do
    project_root = Keyword.get(opts, :project_root, File.cwd!())

    module = opts |> Keyword.fetch!(:module) |> inflect()
    project = base() |> inflect

    generator = inflect_new("Mix.Tasks.#{project.base}.Gen.#{Keyword.fetch!(opts, :generator)}")

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

  # def prewalk({:defmodule, meta, lines}, acc) do
  #   # Pull basic module info out of the file
  #   [{:__aliases__, _aliases_meta, [base | scoped] = full_module} | _] = lines

  #   new_acc =
  #     acc
  #     |> Keyword.put(:full_module, full_module)
  #     # |> Keyword.put(:inflection, inflect(scoped))
  #     |> Keyword.put(:base, base)

  #   {{:defmodule, meta, lines}, new_acc}
  # end

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

  def template_path(generator) do
    "priv/templates/#{generator.lowercase}"
  end

  def base, do: Mix.Phoenix.base()

  def write_generator_module(context) do
    files = [{:eex, "generator.ex", context.generator.path}]
    binding = context |> Keyword.new()

    Mix.Phoenix.copy_from(generator_roots(), "priv/templates/degenerator", binding, files)

    context
  end

  def write_module_template(context) do
    to_quoted_opts = [
      unescape: false,
      warn_on_unnecessary_quotes: false,
      literal_encoder: &{:ok, {:__block__, &2, [&1]}},
      token_metadata: true,
      warnings: false
    ]

    # acc = [moduledoc: "This file was generated by running `command`", auxiliary_modules: []]

    {forms, comments} =
      context.module
      |> Map.fetch!(:path)
      |> File.read!()
      |> Code.string_to_quoted_with_comments!(to_quoted_opts)

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

  defp inflect(aliases) when is_list(aliases) do
    aliases
    |> Enum.map(&Atom.to_string/1)
    |> Enum.join(".")
    |> inflect()
  end

  defp inflect(singular) when is_atom(singular),
    do: singular |> Atom.to_string() |> inflect()

  defp inflect(module) when is_binary(module) do
    module_components =
      module
      |> Macro.camelize()
      |> String.split(".")
      |> Enum.map(&String.to_atom/1)

    module = Module.concat(module_components)

    base = List.first(module_components)
    alias = List.last(module_components)

    lowercase = alias |> to_string() |> Macro.underscore()

    path =
      module.__info__(:compile)
      |> Keyword.fetch!(:source)
      |> Path.relative_to_cwd()

    %{
      alias: alias,
      lowercase: lowercase,
      module: module,
      path: path,
      base: base
    }
  end

  defp inflect_new(module) do
    module_components =
      module
      |> Macro.camelize()
      |> String.split(".")
      |> Enum.map(&Macro.camelize/1)
      |> Enum.map(&String.to_atom/1)

    module = module_components |> Enum.join(".") |> String.to_atom()

    {base, alias} =
      case module_components do
        [:Mix, :Tasks | alias] ->
          {Mix.Task, alias |> Enum.join(".") |> String.to_atom()}
      end

    lowercase =
      alias
      |> to_string()
      |> String.split(".")
      |> Enum.map(&Macro.underscore/1)
      |> Enum.join(".")

    path =
      "lib/" <>
        (base |> to_string() |> Macro.underscore()) <>
        "/" <> lowercase <> ".ex"

    %{
      alias: alias,
      lowercase: lowercase,
      module: module,
      path: path,
      base: base
    }
  end

  defp generator_roots, do: [".", :degenerator]
end