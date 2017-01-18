defmodule Vape do
  def open_file(filename) do
    File.open(filename, [:read, :char_list])
  end

  def line_loop(file, acc_data \\ []) do
    case IO.read(file, :line) do
      :eof -> acc_data
      data -> line_loop(file, acc_data ++ data)
    end
  end

  def tokenize(file) do
    code = line_loop(file)
    :vape_lexer.string(code)
  end

  def parse(tokens) do
    :vape_parser.parse(tokens)
  end
end
