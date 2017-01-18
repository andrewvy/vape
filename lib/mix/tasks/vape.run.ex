defmodule Mix.Tasks.Vape.Run do
  use Mix.Task

  def run(args) do
    args
    |> OptionParser.parse()
    |> case do
      {_, [], _} -> IO.puts("Must provide a file to run")
      {_, [filename], _} -> compile(filename) |> interpret()
      {_, _, _} -> IO.puts("Must only provide a single file")
    end
  end

  def compile(filename) do
    IO.puts("Compiling (#{filename})..")

    with {:ok, file} <- Vape.open_file(filename),
      {:ok, tokens, _} <- Vape.tokenize(file),
      {:ok, parsed_ast} <- Vape.parse(tokens) do
        {:ok, parsed_ast}
    else
      {:error, :enoent} ->
        IO.puts("Could not find file: (#{filename})!")
        {:error, "No file"}
      {:error, {line_number, :vape_parser, errors}} ->
        Enum.each(errors, fn(error) ->
          IO.puts("[error] (#{filename}) Line #{line_number}: #{error}")
        end)
        {:error, "Parser error."}
      error ->
        IO.inspect(error)
        {:error, "???"}
    end
  end

  def interpret({:ok, ast}) do
    IO.puts("[ok] Printing AST..")
    IO.inspect(ast)
  end

  def interpret({:error, _}) do
    IO.puts("[error] Could not compile. Stopping..")
  end
end
