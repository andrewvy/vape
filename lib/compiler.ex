defmodule Vape.Compiler.Context do
  defstruct [
    ast: [],
    filename: "",
    stripped_filename: "",
    debug?: false,
    symbol_table: %Vape.SymbolTable{},
    object_table: %Vape.ObjectTable{}
  ]
end

defmodule Vape.Compiler.ContextUtils do
  def set_context(context) do
    Process.put(:context, context)
  end

  def get_context() do
    Process.get(:context)
  end

  def get_filename() do
    Process.get(:context).filename
  end

  def get_stripped_filename() do
    Process.get(:context).stripped_filename
  end

  def check_symbol_table(identifier) do
    symbol_table = Process.get(:context).symbol_table
    Map.has_key?(symbol_table.symbols, identifier)
  end

  def update_symbol_table(identifier, type) do
    context = Process.get(:context)
    symbol_table = context.symbol_table

    Process.put(
      :context,
      Map.put(context, :symbol_table, %{ symbol_table | symbols: Map.put(symbol_table.symbols, identifier, type) })
    )
  end

  def define_object() do
  end

  def define_function() do
  end

  def define_variable() do
  end
end

defmodule Vape.Compiler do
  @moduledoc """
  Compiler module, where the AST is generated from the file and
  compiler passes are made on the AST.
  """

  require Logger

  # Recursive dir walk to compile each .vape file.
  def compile(filename) do
    if !File.exists?(filename) do
      raise "#{filename} does not exist."
    end

    if Path.extname(filename) != ".vape" do
      raise "#{filename} must use the `.vape` file extension."
    end

    fileroot = Path.dirname(filename)
    files = [filename | Vape.Utils.recursive_file_walk(fileroot)]

    files
    |> Enum.map(&(Task.async(__MODULE__, :compile_single_file, [&1])))
    |> Task.yield_many
    |> Enum.reduce(%Vape.Compiler.Context{}, fn(task, acc) ->
      {_, task_result} = task

      # Yield the result of concurrent compiler tasks
      # If :ok, merge the compiler context with the acc
      # If :error, compiler error has occured with this file.
      case task_result do
        {:ok, result} ->
          {:ok, compiler_context} = result

          # @todo make pretty

          %{
            acc |
            ast: compiler_context.ast,
            filename: compiler_context.filename,
            stripped_filename: compiler_context.stripped_filename,
            symbol_table: compiler_context.symbol_table,
            object_table: %{
              acc.object_table |
              objects: Map.merge(
                         compiler_context.object_table.objects,
                         acc.object_table.objects
                       )
            }
          }
        {:error, _} -> Logger.error("Something wrong happened.")
      end
    end)
  end

  def compile_single_file(filename) do
    if !File.exists?(filename) do
      raise "#{filename} does not exist."
    end

    if Path.extname(filename) != ".vape" do
      raise "#{filename} must use the `.vape` file extension."
    end

    stripped_filename = filename |> Path.basename(".vape")
    context = %Vape.Compiler.Context{filename: filename, stripped_filename: stripped_filename, debug?: true}
    Vape.Compiler.ContextUtils.set_context(context)

    with {:ok, ast} <- generate_ast_from_file(filename) do
      context = Vape.Compiler.ContextUtils.get_context()

      Vape.Compiler.ContextUtils.set_context(%{context |
        ast: ast
      })

      walk(ast)

      {:ok, Vape.Compiler.ContextUtils.get_context()}
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

  def walk(list) when is_list(list) do
    Enum.each(list, fn(ast) ->
      walk(ast)
    end)

    # We'll just pass the AST through without doing anything
    # to it.

    Vape.Compiler.ContextUtils.get_context()
  end

  @types [:integer, :string, :float, :function, :boolean, :null]
  def walk({type, _, _value}) when type in @types do
  end

  def walk({:import, _line, dotted_identifier}) do
    identifier = join_dotted_identifier(dotted_identifier)
    Vape.Compiler.ContextUtils.update_symbol_table(identifier, :import)
  end

  def walk({:object, _line, {:identifier, _ident_line, identifier}, statements}) do
    if to_string(identifier) != Vape.Compiler.ContextUtils.get_stripped_filename() do
      raise "object #{identifier} must match filename #{Vape.Compiler.ContextUtils.get_filename()}"
    end

    Vape.Compiler.ContextUtils.update_symbol_table(to_string(identifier), :object)

    walk(statements)
  end

  def walk({:assign, _line, {:identifier, _ident_line, identifier}, _expression}) do
    Vape.Compiler.ContextUtils.update_symbol_table(to_string(identifier), :assignment)
  end

  def walk({:functiondef, _line, {:identifier, _ident_line, identifier}, {function_params, function_body}}) do
    Vape.Compiler.ContextUtils.update_symbol_table(to_string(identifier), :function)

    function_params |> walk()
    function_body |> walk()
  end

  def walk({:new, node}) do
    node |> walk()
  end

  @temporary_functions ["print"]
  def walk({:functioncall, _line, _dotted_identifier, params}) do
    # identifier = join_dotted_identifier(dotted_identifier)

    # [temporary]
    # @todo(vy): Must add all functions to symbol table before checking function calls.

    # if not identifier in @temporary_functions do
    #   case Vape.Compiler.ContextUtils.check_symbol_table(identifier) do
    #     false -> raise "On line #{line}, function call to #{identifier}() does not exist."
    #     true -> ""
    #   end
    # end

    Enum.each(params, fn(param) ->
      case param do
        {:identifier, line, param_identifier} when is_list(param_identifier) ->
          joined_param_identifier = join_dotted_identifier(param)
          case Vape.Compiler.ContextUtils.check_symbol_table(joined_param_identifier) do
            false -> raise "On line #{line}, parameter referencing `#{joined_param_identifier}` does not exist in the scope."
            true -> ""
          end
        _ -> true
      end
    end)
  end

  def walk({:op, _line, _operation, _lhs_exp, _rhs_exp}) do
  end

  def walk({:identifier, _line, dotted_identifier}) when is_list(dotted_identifier) do
  end

  def walk({_, _, list}) when is_list(list) do
    list |> walk()
  end

  def walk({_, _, _, list}) when is_list(list) do
    list |> walk()
  end

  def walk({_, _, _}) do
  end

  def join_dotted_identifier({:identifier, _, identifiers}) when is_list(identifiers) do
    identifiers
    |> Enum.map_join(".", fn({:identifier, _, name}) -> name end)
  end
end
