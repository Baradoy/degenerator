defmodule Mix.Tasks.<%= project %>.Gen.<%= name_inflection.scoped %> do
  @moduledoc """
    Generate a <%= name_inflection.singular %>

    > mix <%= generator_downcase_name %>

    will create
      lib/<%= project %>/<%= module_inflection.path %>.ex

    > mix <%= generator_downcase_name %> --project MyProject --module MyModule

    will create
      lib/my_project/my_module.ex
  """

  @shortdoc "Generate a <%= name_inflection.singular %>"
  @template_path "<%= template_path %>"

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
    project_path = project |> Macro.underscore() |> String.downcase()
    module_name = Keyword.get(opts, :module_name)

    module_inflection = opts |> Keyword.get(:module_name) |> Mix.Phoenix.inflect() |> Map.new()
    module_path = Path.join(["lib", project_path, module_inflection.path])

    files = [{:eex, module_inflection.path <> ".ex", module_path <> ".ex"}]
    binding = [inflection: module_inflection, project: project, module_name: module_name]

    Mix.Phoenix.copy_from(generator_paths(), @template_path, binding, files)

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

 defp generator_paths, do: [".", :<%= app %>, :degenerator]
end
