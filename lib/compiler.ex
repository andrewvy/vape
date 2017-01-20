defmodule Vape.Compiler.Context do
  defstruct filename: "", stripped_filename: "", debug?: false, pid: nil, symbol_table: %Vape.SymbolTable{}
end

defmodule Vape.Compiler.ContextServer do
  use GenServer

  def start_link(context) do
    GenServer.start_link(__MODULE__, context, [])
  end

  def init(context) do
    {:ok, %{context | pid: self()}}
  end

  def get_context(pid) do
    pid |> GenServer.call(:get_context)
  end

  def get_filename(pid) do
    pid |> GenServer.call(:get_filename)
  end

  def get_stripped_filename(pid) do
    pid |> GenServer.call(:get_stripped_filename)
  end

  def add_to_symbol_table(pid, identifier, type) do
    pid |> GenServer.call({:add_to_symbol_table, identifier, type})
  end

  def check_symbol_table(pid, identifier) do
    pid |> GenServer.call({:check_symbol_table, identifier})
  end

  def handle_call(:get_filename, _from, state) do
    {:reply, state.filename, state}
  end

  def handle_call(:get_stripped_filename, _from, state) do
    {:reply, state.stripped_filename, state}
  end

  def handle_call(:get_context, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:add_to_symbol_table, identifier, type}, _from, state) do
    {:reply, :ok, update_symbol_table(state, identifier, type)}
  end

  def handle_call({:check_symbol_table, identifier}, _from, state) do
    symbol_table = state.symbol_table

    {:reply, Map.has_key?(symbol_table.symbols, identifier), state}
  end

  defp update_symbol_table(context, identifier, type) do
    symbol_table = context.symbol_table

    %{
      context |
      symbol_table: %{ symbol_table | symbols: Map.put(symbol_table.symbols, identifier, type) }
    }
  end
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
    {:ok, context_pid} = Vape.Compiler.ContextServer.start_link(context)

    with {:ok, ast} <- generate_ast_from_file(filename) do
      {:ok, walk(ast, context_pid), context_pid}
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

  def walk({:import, _line, dotted_identifier}, context) do
    identifier = join_dotted_identifier(dotted_identifier)
    context |> Vape.Compiler.ContextServer.add_to_symbol_table(identifier, :import)
  end

  def walk({:object, _line, {:identifier, _ident_line, identifier}, statements}, context) do
    if to_string(identifier) != Vape.Compiler.ContextServer.get_stripped_filename(context) do
      raise "object #{identifier} must match filename #{Vape.Compiler.ContextServer.get_filename(context)}"
    end

    context |> Vape.Compiler.ContextServer.add_to_symbol_table(to_string(identifier), :object)

    walk(statements, context)
  end

  def walk({:assign, _line, {:identifier, _ident_line, identifier}, _expression}, context) do
    context |> Vape.Compiler.ContextServer.add_to_symbol_table(to_string(identifier), :assignment)
  end

  def walk({:functiondef, _line, {:identifier, _ident_line, identifier}, {function_params, function_body}}, context) do
    context |> Vape.Compiler.ContextServer.add_to_symbol_table(to_string(identifier), :function)

    function_params |> walk(context)
    function_body |> walk(context)
  end

  def walk({:new, node}, context) do
    node |> walk(context)
  end

  @temporary_functions ["print"]
  def walk({:functioncall, line, dotted_identifier, params}, context) do
    identifier = join_dotted_identifier(dotted_identifier)

    if not identifier in @temporary_functions do
      case context |> Vape.Compiler.ContextServer.check_symbol_table(identifier) do
        false -> raise "On line #{line}, function call to #{identifier}() does not exist."
        true -> ""
      end
    end

    Enum.each(params, fn(param) ->
      case param do
        {:identifier, line, param_identifier} when is_list(param_identifier) ->
          joined_param_identifier = join_dotted_identifier(param)
          case context |> Vape.Compiler.ContextServer.check_symbol_table(joined_param_identifier) do
            false -> raise "On line #{line}, parameter referencing `#{joined_param_identifier}` does not exist in the scope."
            true -> ""
          end
      end
    end)
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

  def join_dotted_identifier({:identifier, _, identifiers}) when is_list(identifiers) do
    identifiers
    |> Enum.map_join(".", fn({:identifier, _, name}) -> name end)
  end

  def generate_symbol_table() do
  end
end
