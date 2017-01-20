defmodule Vape.VM do
  defstruct ast: [], stackframes: [], symbol_table: %Vape.SymbolTable{}
end

defmodule Vape.Interpreter do
  @moduledoc """
  Simple direct AST interpreter.
  """

  def run(%Vape.VM{} = vm) do
    IO.inspect(vm.ast)
  end
end
