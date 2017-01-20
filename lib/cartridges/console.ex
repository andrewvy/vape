defmodule Vape.Cartridges.Console do
  @moduledoc """
  Cartridge for providing the Console.
  """

  def print(string) do
    IO.puts(string)
  end
end
