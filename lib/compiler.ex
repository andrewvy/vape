defmodule Vape.Compiler.Context do
  defstruct filename: "", stripped_filename: "", debug?: false
end

defmodule Vape.Compiler do
  @moduledoc """
  Compiler module, where the AST is generated from the file and
  compiler passes are made on the AST.
  """

  require Logger

  def compile(filename) do
    if !File.exists?(filename) do
      raise "#{filename} does not exist."
    end

    if Path.extname(filename) != ".vape" do
      raise "#{filename} must use the `.vape` file extension."
    end

    stripped_filename = filename |> Path.basename(".vape")
    context = %Vape.Compiler.Context{filename: filename, stripped_filename: stripped_filename, debug?: true}

    Logger.info("Compiling `#{filename}`..")

    with {:ok, ast} <- generate_ast_from_file(filename) do
      Logger.info("1st compiler pass on `#{filename}`..")
      {:ok, walk(ast, context), %Vape.SymbolTable{}}
    else
      {:error, errors} when is_list(errors) ->
        Enum.each(errors, &Logger.error/1)
        {:error, errors}
      {:error, error} ->
        error |> Logger.error()
        {:error, error}
    end
  end

  def generate_ast_from_file(filename) do
    with {:ok, file} <- Vape.open_file(filename),
      {:ok, tokens, _} <- Vape.tokenize(file),
      {:ok, parsed_ast} <- Vape.parse(tokens) do
        {:ok, parsed_ast}
    else
      {:error, :enoent} ->
        {:error, "No file"}
      {:error, {line_number, :vape_parser, errors}} ->
        errors = Enum.map(errors, fn(error) ->
          "(#{filename}) Line #{line_number}: #{error}"
        end)
        {:error, errors}
      _ ->
        {:error, "???"}
    end
  end

  def walk(list, context) when is_list(list) do
    Enum.each(list, fn(ast) ->
      ast |> walk(context)
    end)

    # We'll just pass the AST through without doing anything
    # to it.

    list
  end

  @types [:integer, :string, :float, :function, :boolean, :null]
  def walk({type, _, _value}, _context) when type in @types do
  end

  def walk({:import, _line, _dotted_identifier}, _context) do
  end

  def walk({:object, _line, {:identifier, _ident_line, identifier}, statements}, context) do
    if to_string(identifier) != context.stripped_filename do
      raise "object #{identifier} must match filename #{context.filename}"
    end

    walk(statements, context)
  end

  def walk({:assign, _line, {:identifier, _ident_line, _identifier}, expression_list}, context) do
    Enum.each(expression_list, fn(expression) ->
      expression |> walk(context)
    end)
  end

  def walk({:functiondef, _line, {:identifier, _ident_line, _identifier}, {function_params, function_body}}, context) do
    function_params |> walk(context)
    function_body |> walk(context)
  end

  def walk({:new, node}, context) do
    node |> walk(context)
  end

  def walk({:functioncall, _line, _dotted_identifier, _params}, _context) do
  end

  def walk({:op, _line, _operation, _lhs_exp, _rhs_exp}, _context) do
  end

  def walk({:identifier, _line, dotted_identifier}, _context) when is_list(dotted_identifier) do
  end

  def walk({_, _, list}, context) when is_list(list) do
    list |> walk(context)
  end

  def walk({_, _, _, list}, context) when is_list(list) do
    list |> walk(context)
  end

  def walk({_, _, _}, _context) do
  end

  def generate_symbol_table() do
  end
end
