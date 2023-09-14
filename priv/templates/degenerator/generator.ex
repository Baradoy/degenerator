defmodule Mix.Tasks.<%= generator.alias %> do
  @moduledoc """
  Generate a <%= module.alias %> Module

  > mix <%= generator.lowercase %>

  will create
    <%= module.path %>

  > mix <%= generator.lowercase %> --project MyProject --module MyModule

  will create
    lib/my_project/my_module.ex
  """

  @shortdoc "Generate a <%= module.alias %> Module"
  @templates_path "<%= templates_root %>/"

  @module_templates [
    %{path: "<%= template_path %>", default_module_name: "<%= module.alias %>", lowercase: "<%= module.lowercase %>"}
  ]

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    case OptionParser.parse(args, strict: [{:project, :string} | build_module_switches()]) do
      {opts, [], []} -> generate(opts ++ defaults())
      _ -> usage()
    end
  end

  def generate(opts) do
    project = Keyword.get(opts, :project)

    for template <- @module_templates do
      destinatin_path = template |> get_template_target(opts) |> destinatin_path(project)

      module_name = get_template_alias(template, opts)
      module_inflection = module_name |> Mix.Phoenix.inflect() |> Map.new()

      files = [{:eex, template[:path], destinatin_path}]
      binding = [
        inflection: module_inflection, project: project, module_name: module_name
      ]

      Mix.Phoenix.copy_from(generator_roots(), @templates_path, binding, files)
    end

    print_shell_instructions()
  end

  @doc false
  def print_shell_instructions() do
    Mix.shell().info("""
    Additional instructions
    """)
  end

  defp usage do
    options =
      @module_templates
      |> Enum.map(fn template ->
        ~s(--#{template.lowercase}_name #{template.default_module_name} --#{template.lowercase}_path #{template.path})
      end)
      |> Enum.join(" ")
      |> String.replace("_", "-")

    Mix.shell().info("""
    Usage: mix <%= generator.lowercase %>

    You an provide options for individual modules:
      mix <%= generator.lowercase %> #{options}
    """)
  end

  defp defaults do
    base = Mix.Project.config() |> Keyword.fetch!(:app) |> to_string() |> Macro.camelize()

    [project: base]
  end

  defp generator_roots, do: [".", :<%= app %>, :degenerator]

  defp destinatin_path(path, project) do
    project = project |> Macro.underscore() |> String.downcase()
    String.replace(path, "my_project", project)
  end

  # Build switches based off of the given module templates
  # When there are multiple modules in a generator, we need to override them individually
  defp build_module_switches() do
    Enum.flat_map(@module_templates, fn template ->
      [
        {(template.lowercase <> "_path") |> String.to_atom(), :string},
        {(template.lowercase <> "_name") |> String.to_atom(), :string}
      ]
    end)
  end

  defp get_template_target(template, otps), do:
    Keyword.get(otps, template.lowercase <> "_path" |> String.to_atom(), template.path)

  defp get_template_alias(template, otps), do:
    Keyword.get(otps, template.lowercase <> "_name" |> String.to_atom(), template.default_module_name)
end
