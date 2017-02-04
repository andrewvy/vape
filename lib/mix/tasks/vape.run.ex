defmodule Mix.Tasks.Vape.Run do
  use Mix.Task

  require Logger

  def run(args) do
    args
    |> OptionParser.parse()
    |> case do
      {_, [], _} -> Logger.error("Must provide a file to run")
      {_opts, [filename], _} ->
        {:ok, ast} = Vape.Compiler.compile(filename)
        vm = %Vape.VM{ast: ast}
        Vape.Interpreter.run(vm)
      {_, _, _} -> Logger.error("Must only provide a single file")
    end
  end
end
