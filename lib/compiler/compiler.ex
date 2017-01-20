defmodule Vape.Compiler do
  require Logger

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
          "[error] (#{filename}) Line #{line_number}: #{error}"
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
  end

  def walk({:import, _line, dottedname}, _context) do
    Logger.debug("Importing `#{dotted_name_to_string(dottedname)}`")
  end

  def walk({:object, _line, {:identifier, _ident_line, identifier}, statements}, context) do
    Logger.debug("New object definition `#{identifier}`")

    walk(statements, context)
  end

  def walk({:assign, _line, {:identifier, _ident_line, identifier}, expression_list}, context) do
    Logger.debug("Assigning `#{identifier}` to:")
    Enum.each(expression_list, fn(expression) ->
      case expression do
        {:new, exp} ->
          exp |> walk(context)
        {type, _, value} ->
          Logger.debug("> [#{type}] (#{value})")
        array when is_list(array) ->
          Logger.debug("> Array of: ")
          Enum.each(array, fn({type, _, value}) ->
            Logger.debug("> > [#{type}] (#{value})")
          end)
        {:op, _, _, _, _} = op -> op |> walk(context)
      end
    end)
  end

  def walk({:functiondef, _line, {:identifier, _ident_line, identifier}, {function_params, function_body}}, context) do
    Logger.debug("Defining function (#{identifier})")
    function_params |> walk(context)
    function_body |> walk(context)
  end

  def walk({:new, node}, context) do
    node |> walk(context)
  end

  def walk({:functioncall, _line, dotted_name, params}, _context) do
    Logger.debug("Calling function `#{dotted_name_to_string(dotted_name)}()` with params: #{params_to_string(params)}")
  end

  @types [:integer, :string, :float, :function, :boolean, :null]

  def walk({:op, _line, operation, lhs_exp, rhs_exp}, context) do
    case lhs_exp do
      {type, _, _} ->
        if type in @types do
          Logger.debug("#{params_to_string(lhs_exp)}")
        end
      _ -> false
    end

    case rhs_exp do
      {type, _, _} ->
        if type in @types do
          Logger.debug("#{params_to_string(rhs_exp)}")
        end
      _ -> false
    end


    lhs_exp |> walk(context)
    Logger.debug("#{Atom.to_string(operation)}")
    rhs_exp |> walk(context)
  end

  def walk({:identifier, _line, dotted_identifier}, _context) when is_list(dotted_identifier) do
    Logger.debug("Reference `#{dotted_name_to_string(dotted_identifier)}`")
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

  defp dotted_name_to_string(dotted_name) when is_list(dotted_name) do
    Enum.map_join(dotted_name, ".", fn({:identifier, _, identifier}) -> identifier end)
  end

  defp params_to_string({type, _, identifier}), do: "[#{Atom.to_string(type)}] #{identifier}"
  defp params_to_string([]), do: "[]"
  defp params_to_string(params) when is_list(params) do
    Enum.map_join(params, ".", &params_to_string/1)
  end
end
