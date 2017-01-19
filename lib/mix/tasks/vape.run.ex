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
    Vape.Compiler.generate_ast_from_file(filename)
  end

  def interpret({:ok, ast}) do
    IO.puts("[ok] Walking AST..")
    Vape.Compiler.walk(ast)
  end

  def interpret({:error, errors}) when is_list(errors) do
    Enum.each(errors, &IO.puts/1)
  end

  def interpret({:error, error}) do
    error |> IO.puts()
  end
end
