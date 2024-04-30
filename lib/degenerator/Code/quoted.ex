defmodule Degenerator.Code.Quoted do
  @moduledoc """
  Functions for dealing with code in quoted form
  """

  def module_attribute_append(value, attribute, opts \\ []) when is_atom(attribute) do
    fn
      {:@, _, [{^attribute, _, [{:__block__, _, _}]}]} = quoted, acc ->
        update_in_module_attribute(quoted, acc, value, opts)

      quoted, acc ->
        {quoted, acc}
    end
  end

  defp update_in_module_attribute(quoted, context, value, opts) do
    updated =
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
        fn module_attribute ->
          (module_attribute ++ [Code.string_to_quoted!(value)])
          |> sort(opts)
          |> uniq(opts)
        end
      )

    {updated, context}
  end

  defp sort(enum, opts) do
    sorter = Keyword.get(opts, :sorter, &<=/2)
    mapper = Keyword.get(opts, :mapper, &elem(&1, 2))

    if Keyword.get(opts, :sort, false) do
      Enum.sort_by(enum, mapper, sorter)
    else
      enum
    end
  end

  defp uniq(enum, opts) do
    mapper = Keyword.get(opts, :mapper, &elem(&1, 2))

    if Keyword.get(opts, :sort, false) do
      Enum.uniq_by(enum, mapper)
    else
      enum
    end
  end

  def passthrough(quoted, acc), do: {quoted, acc}
end
