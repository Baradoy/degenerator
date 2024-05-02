defmodule Degenerator.Code do
  @moduledoc """
  Traverse and modify code
  """

  alias Degenerator.Code.Quoted

  def write_after_traversal(source_path, target_path, context, opts \\ []) do
    prewalk = Keyword.get(opts, :prewalk, &Quoted.passthrough/2)
    postwalk = Keyword.get(opts, :postwalk, &Quoted.passthrough/2)

    {forms, comments} =
      source_path
      |> File.read!()
      |> Code.string_to_quoted_with_comments!(to_quoted_opts())

    {forms, context} =
      Macro.traverse(
        forms,
        context,
        prewalk,
        postwalk
      )

    to_algebra_opts = [comments: comments]
    doc = Code.Formatter.to_algebra(forms, to_algebra_opts)
    source = Inspect.Algebra.format(doc, 98) |> Enum.join()

    Mix.Generator.create_file(target_path, source)

    context
  end

  def string_to_quoted!(string), do: Code.string_to_quoted!(string, to_quoted_opts())

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
