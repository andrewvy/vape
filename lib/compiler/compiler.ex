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

  def walk(list) when is_list(list) do
    Enum.each(list, fn(ast) ->
      ast |> walk()
    end)
  end

  def walk({:import, _line, dottedname}) do
    Logger.debug("Importing `#{dotted_name_to_string(dottedname)}`")
  end

  def walk({:object, _line, {:identifier, _ident_line, identifier}, statements}) do
    Logger.debug("New object definition `#{identifier}`")

    walk(statements)
  end

  def walk({:assign, _line, {:identifier, _ident_line, identifier}, expression_list}) do
    Logger.debug("Assigning `#{identifier}` to:")
    Enum.each(expression_list, fn(expression) ->
      case expression do
        {:new, exp} ->
          exp |> walk()
        {type, _, value} ->
          Logger.debug("> [#{type}] (#{value})")
        array when is_list(array) ->
          Logger.debug("> Array of: ")
          Enum.each(array, fn({type, _, value}) ->
            Logger.debug("> > [#{type}] (#{value})")
          end)
      end
    end)
  end

  def walk({:functiondef, _line, {:identifier, _ident_line, identifier}, {function_params, function_body}}) do
    Logger.debug("Defining function (#{identifier})")
    function_params |> walk()
    function_body |> walk()
  end

  def walk({:new, node}) do
    node |> walk()
  end

  def walk({:functioncall, _line, dotted_name, params}) do
    Logger.debug("Calling function `#{dotted_name_to_string(dotted_name)}()` with params: #{params_to_string(params)}")
  end

  def walk({_, _, list}) when is_list(list) do
    list |> walk()
  end

  def walk({_, _, _, list}) when is_list(list) do
    list |> walk()
  end

  def walk({_, _, _}) do
  end

  def generate_symbol_table() do
  end

  defp dotted_name_to_string(dotted_name) when is_list(dotted_name) do
    Enum.map_join(dotted_name, ".", fn({:identifier, _, identifier}) -> identifier end)
  end

  defp params_to_string([]), do: "[]"
  defp params_to_string(params) when is_list(params) do
    Enum.map_join(params, ".", fn({type, _, identifier}) -> "[#{Atom.to_string(type)}] #{identifier}" end)
  end
end
