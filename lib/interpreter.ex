defmodule Vape.VM.MemorySpace do
  defstruct space: %{}
end

defmodule Vape.VM.ReferenceCounter do
  @moduledoc """
  Keeps track of objects and their associated reference count
  so it can be garbage collected with its refc == 0.
  """

  defstruct reference_counter: %{}
end

defmodule Vape.VM.ObjectTable do
  defstruct objects: %{}, id_counter: 0
end

defmodule Vape.VM do
  defstruct [
    ast: [],
    stack_pointer: 0,
    stackframes: [%{}],
    object_table: %Vape.VM.ObjectTable{},
    memory_space: %Vape.VM.MemorySpace{},
    garbage_collector: %Vape.VM.ReferenceCounter{}
  ]
end

defmodule Vape.VM.Process do
  use GenServer

  def start_link(%Vape.VM{} = vm) do
    GenServer.start_link(__MODULE__, vm, [])
  end

  def define_in_scope(pid, identifier, value) do
    pid |> GenServer.cast({:define_in_scope, identifier, value})
  end

  def lookup_in_scope(pid, identifier) do
    pid |> GenServer.call({:lookup_in_scope, identifier})
  end

  def get_stack_frames(pid) do
    pid |> GenServer.call(:get_stack_frames)
  end

  def handle_cast({:define_in_scope, identifier, value}, state) do
    {:noreply, put_in_scope(state, identifier, value)}
  end

  def handle_call({:lookup_in_scope, identifier}, _from, state) do
    stackframe = Enum.at(state.stackframes, state.stack_pointer)
    {:reply, Map.get(stackframe, identifier), state}
  end

  def handle_call(:get_stack_frames, _from, state) do
    {:reply, state.stackframes, state}
  end

  defp put_in_scope(state, identifier, value) do
    %{
      state |
      stackframes: List.update_at(state.stackframes, state.stack_pointer, fn(old_frame) ->
        Map.put(old_frame, identifier, value)
      end)
    }
  end
end

defmodule Vape.Interpreter do
  @moduledoc """
  Simple direct AST interpreter.
  """

  @types [:string, :integer, :float, :boolean]

  @temporary_functions %{
    "print" => {1, &__MODULE__.__print/1}
  }

  def run(%Vape.VM{} = vm) do
    {:ok, vm_pid} = Vape.VM.Process.start_link(vm)

    interpret(vm.ast, vm_pid)
  end

  def interpret(ast, vm_pid) when is_list(ast) and is_pid(vm_pid) do
    Enum.map(ast, &(interpret(&1, vm_pid)))
  end

  def interpret({:import, _, _dotted_identifier}, _vm_pid) do
  end

  def interpret({:object, _, {:identifier, _, identifier}, body}, vm_pid) do
    vm_pid |> Vape.VM.Process.define_in_scope(to_string(identifier), :object)

    Enum.map(body, &(interpret(&1, vm_pid)))
  end

  def interpret({:declaration, _, body}, vm_pid) do
    Enum.map(body, &(interpret(&1, vm_pid)))
  end

  def interpret({:assign, _, {:identifier, _, identifier}, rhs_exp}, vm_pid) do
    value =
      case rhs_exp do
        {:identifier, _, dotted_identifier} when is_list(dotted_identifier) ->
          vm_pid |> Vape.VM.Process.lookup_in_scope(join_dotted_identifier(rhs_exp))
        {:identifier, _, identifier} ->
          vm_pid |> Vape.VM.Process.lookup_in_scope(identifier)
        _ ->
          interpret(rhs_exp, vm_pid)
      end

    vm_pid |> Vape.VM.Process.define_in_scope(to_string(identifier), value)
  end

  def interpret({:functiondef, _, {:identifier, _, identifier}, {_params, body}}, vm_pid) do
    # if main() is defined, immediately execute.
    case to_string(identifier) do
      "main" -> interpret(body, vm_pid)
      _ -> vm_pid |> Vape.VM.Process.define_in_scope(to_string(identifier), body)
    end
  end

  def interpret({:functioncall, _, dotted_identifier, params}, vm_pid) do
    joined_identifier = join_dotted_identifier(dotted_identifier)

    if Map.has_key?(@temporary_functions, joined_identifier) do
      {func_arity, func} = @temporary_functions[joined_identifier]

      values = Enum.map(params, fn(param) ->
        case param do
          {:identifier, _, dotted_identifier} when is_list(dotted_identifier) ->
            vm_pid |> Vape.VM.Process.lookup_in_scope(join_dotted_identifier(param))
          {:identifier, _, identifier} ->
            vm_pid |> Vape.VM.Process.lookup_in_scope(identifier)
          _ ->
            interpret(param, vm_pid)
        end
      end)

      if Enum.count(values) == func_arity do
        apply(func, values)
      else
        raise "Tried calling built-in function #{joined_identifier}() with #{Enum.count(values)} parameters, but its arity is #{func_arity}"
      end
    else
      # Calling a non-built-in function, look up the function AST in the symbol table.
    end
  end

  def interpret({:op, _line, operation, lhs_exp, rhs_exp}, vm_pid) do
    lhs =
      case lhs_exp do
        {:op, _, _, _, _} -> interpret(lhs_exp, vm_pid)
        {:identifier, _, dotted_identifier} when is_list(dotted_identifier) ->
          vm_pid |> Vape.VM.Process.lookup_in_scope(join_dotted_identifier(lhs_exp))
        {:identifier, _, identifier} ->
          vm_pid |> Vape.VM.Process.lookup_in_scope(identifier)
        {type, _, value} when type in @types -> value
      end

    rhs =
      case rhs_exp do
        {:op, _, _, _, _} -> interpret(rhs_exp, vm_pid)
        {:identifier, _, dotted_identifier} when is_list(dotted_identifier) ->
          vm_pid |> Vape.VM.Process.lookup_in_scope(join_dotted_identifier(rhs_exp))
        {:identifier, _, identifier} ->
          vm_pid |> Vape.VM.Process.lookup_in_scope(identifier)
        {type, _, value} when type in @types -> value
      end

    try do
      case operation do
        :+ -> lhs + rhs
        :- -> lhs - rhs
        :* -> lhs * rhs
        :/ -> lhs / rhs
        :^ -> :math.pow(lhs, rhs)
        :% -> rem(lhs, rhs)
        :== -> lhs == rhs
        :<= -> lhs <= rhs
        :>= -> lhs >= rhs
        :< -> lhs < rhs
        :> -> lhs > rhs
      end
    rescue
      _ -> raise "[error] Tried to do operation (#{Atom.to_string(operation)}) on lhs: #{inspect lhs}, rhs: #{inspect rhs}"
    end
  end

  def interpret({type, _, value}, _vm_pid) when type in @types do
    value
  end

  def join_dotted_identifier({:identifier, _, identifiers}) when is_list(identifiers) do
    identifiers
    |> Enum.map_join(".", fn({:identifier, _, name}) -> name end)
  end

  def __print(value) do
    IO.puts(value)
  end
end
