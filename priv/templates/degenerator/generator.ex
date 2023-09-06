defmodule Mix.Tasks.<%= project %>.Gen.<%= generator_inflection.scoped %> do
  @moduledoc """
    Generate a <%= generator_inflection.singular %>

    > mix <%= generator_downcase_name %>

    will create
      lib/<%= project %>/<%= module_inflection.path %>.ex

    > mix <%= generator_downcase_name %> --project MyProject --module MyModule

    will create
      lib/my_project/my_module.ex
  """

  @shortdoc "Generate a <%= generator_inflection.singular %>"
  @templates_path "<%= templates_root %>/"

  @templates [
    %{path: "<%= template_path %>", default_module_name: "<%= module_inflection.scoped %>"}
  ]

 use Mix.Task

 @impl Mix.Task
 def run(args) do
   case OptionParser.parse(args, switches: [name: :string, path: :string]) do
     {opts, [], []} -> generate(opts ++ defaults())
     _ -> usage()
   end
  end

  def generate(opts) do
    project = Keyword.get(opts, :project)

    for template <- @templates do
      destinatin_path = destinatin_path(template[:path], project)

      module_name = Keyword.get(opts, :module_name, template[:default_module_name])
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
   Mix.shell().info("""
   Usage: mix <%= generator_downcase_name %>
   """)
 end

 defp defaults do
   base = Mix.Project.config() |> Keyword.fetch!(:app) |> to_string() |> Macro.camelize()

   [
     project: base,
     module_name: "<%= module_inflection.scoped %>"
   ]
 end

 defp generator_roots, do: [".", :<%= app %>, :degenerator]

 defp destinatin_path(path, project) do
   project = project |> Macro.underscore() |> String.downcase()
   String.replace(path, "my_project", project)
 end
end
