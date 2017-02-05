defmodule Vape.Utils do
  def recursive_file_walk(path) do
    cond do
      File.regular?(path) -> [path]
      File.dir?(path) ->
        File.ls!(path)
        |> Enum.map(&Path.join(path, &1))
        |> Enum.map(&recursive_file_walk/1)
        |> Enum.concat
      true -> []
    end
  end
end
