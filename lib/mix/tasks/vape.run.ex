defmodule Mix.Tasks.Vape.Run do
  use Mix.Task

  require Logger

  def run(args) do
    args
    |> OptionParser.parse()
    |> case do
      {_, [], _} -> Logger.error("Must provide a file to run")
      {_opts, [filename], _} -> Vape.Compiler.compile(filename)
      {_, _, _} -> Logger.error("Must only provide a single file")
    end
  end
end
