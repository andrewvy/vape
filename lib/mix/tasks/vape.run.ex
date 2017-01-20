defmodule Mix.Tasks.Vape.Run do
  use Mix.Task

  def run(args) do
    args
    |> OptionParser.parse()
    |> case do
      {_, [], _} -> IO.puts("Must provide a file to run")
      {opts, [filename], _} ->
        context = %Vape.Compiler.Context{filename: filename, debug?: opts[:debug]}
        compile(filename) |> interpret(context)
      {_, _, _} -> IO.puts("Must only provide a single file")
    end
  end

  def compile(filename) do
    IO.puts("Compiling (#{filename})..")
    Vape.Compiler.generate_ast_from_file(filename)
  end

  def interpret({:ok, ast}, context) do
    IO.puts("[ok] Walking AST..")
    Vape.Compiler.walk(ast, context)
  end

  def interpret({:error, errors}, _context) when is_list(errors) do
    Enum.each(errors, &IO.puts/1)
  end

  def interpret({:error, error}, _context) do
    error |> IO.puts()
  end
end
