defmodule Lpex do
  def open_file(filename) do
    File.open(filename, [:read, :char_list])
  end

  def line_loop(file, acc_data \\ []) do
    case IO.read(file, :line) do
      :eof -> acc_data
      data -> line_loop(file, acc_data ++ data)
    end
  end

  def tokenize(filename \\ "test.c") do
    {:ok, file} = open_file(filename)
    code = line_loop(file)
    {:ok, tokens, _} = :lpc.string(code)

    File.close(file)

    tokens
  end

  def parse(tokens) do
    :lpc_parser.parse(tokens)
  end
end
