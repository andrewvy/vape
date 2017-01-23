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

defmodule Vape.ObjectDefinition do
  @moduledoc """
  This struct defines an Object.
  """

  defstruct [
    identifier: "",
    instance_variables: %{},
    functions: %{}
  ]
end

defmodule Vape.FunctionDefinition do
  @moduledoc """
  This struct defines a Function.
  """

  defstruct [
    identifier: "",
    arity: 0,
    parameters: [],
    ast: []
  ]
end

defmodule Vape.ObjectInstance do
  defstruct [
    id: 0,
    object_identifier: "",
    stackframe: %{}
  ]
end

defmodule Vape.VM.ObjectTable do
  defstruct objects: %{}, id_counter: 0
end

defmodule Vape.VM do
  defstruct [
    # [temporary]
    # Holds the entire AST. (idk)
    ast: [],

    # Points to the current stackframe being used.
    stack_pointer: 0,

    # Points to the current instance of the object.
    object_pointer: 0,

    # [temporary]
    # Used to reference the current object that is being
    # defined so we can add function definitions to it.
    defined_object_pointer: "",

    # Holds a list of stackframes, that will get popped and pushed.
    stackframes: [%{}],

    # Holds a table of ObjectDefinitions.
    object_table: %{},

    # Space for instantiated objects.
    memory_space: %Vape.VM.MemorySpace{},

    # [temporary]
    # Holds a simple reference counting mechanism to garbage collect
    # objects when they are no longer referenced.
    garbage_collector: %Vape.VM.ReferenceCounter{}
  ]
end

defmodule Vape.VM.Process do
  use GenServer

  def start_link(%Vape.VM{} = vm) do
    GenServer.start_link(__MODULE__, vm, [])
  end

  @doc """
  Defines a variable within the current stackframe, as indicated by
  the VM's stack pointer.
  """
  def define_in_scope(pid, identifier, value) do
    pid |> GenServer.cast({:define_in_scope, identifier, value})
  end

  @doc """
  Look up a variable name within the current stackframe, as indicated
  by the VM's stack pointer.
  """
  def lookup_in_scope(pid, identifier) do
    pid |> GenServer.call({:lookup_in_scope, identifier})
  end

  @doc """
  Defines an object, this will put the object within our object table
  with its identifier and associated object definition.

  This object definition will contain its functions AST, as well as its
  exported functions and instance variables.
  """
  def define_object(pid, %Vape.ObjectDefinition{} = object_definition) do
    pid |> GenServer.cast({:define_object, object_definition})
  end


  @doc """
  Defines a function, this will put the function definition into the
  current object, using the VM's current `defined_object_pointer`.
  """
  def define_function(pid, %Vape.FunctionDefinition{} = function_definition) do
    pid |> GenServer.cast({:define_function, function_definition})
  end

  @doc """
  Returns an ObjectDefinition if it exists currently within our object
  table.

  Otherwise, it means the identifier in question does not reference a
  defined Object.
  """
  def lookup_object_definition(pid, identifier) do
    pid |> GenServer.call({:lookup_object_definition, identifier})
  end

  @doc """
  Return current ObjectDefinition, using the VM's current `defined_object_pointer`.
  """
  def lookup_current_object_definition(pid) do
    pid |> GenServer.call(:lookup_current_object_definition)
  end

  @doc """
  Given an ObjectDefinition, instantiates an object from that definition
  and returns an object identifier to that new instance.

  This instantiated object is then stored in the VM's memory space.
  """
  @spec instantiate_object(pid(), String.t) :: {:ok, {:object, non_neg_integer()}} | {:error, :undefined_object}
  def instantiate_object(_pid, _identifier) do
    # @todo(vy)
    # Create a %Vape.ObjectInstance{} and put it in VM MemorySpace.
    # Return that object's unique identifier.
  end

  @doc """
  [debug]

  Internal debug function to dump all the stackframes of the VM process.
  """
  def get_stack_frames(pid) do
    pid |> GenServer.call(:get_stack_frames)
  end

  # GenServer Callbacks

  def handle_cast({:define_in_scope, identifier, value}, state) do
    {:noreply, put_in_scope(state, identifier, value)}
  end

  def handle_cast({:define_object, object_definition}, state) do
    {:noreply, update_object_definition(state, object_definition)}
  end

  def handle_cast({:define_function, function_definition}, state) do
    {:noreply, define_function_in_object(state, function_definition)}
  end

  def handle_call({:lookup_object_definition, identifier}, _from, state) do
    {:reply, Map.get(state.object_table, identifier), state}
  end

  def handle_call(:lookup_current_object_definition, _from, state) do
    {:reply, Map.get(state.object_table, state.defined_object_pointer), state}
  end

  # {:lookup_in_scope, identifier}
  # Given an identifier, looks up within the current stackframe to find
  # that variable.
  #
  # Else, if that variable does not exist within the current stackframe,
  # check if the current object has the variable.
  #
  # See https://github.com/andrewvy/vape/issues/2 for scope rules.
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

  defp define_function_in_object(state, function_definition) do
    object_definition = Map.get(state.object_table, state.defined_object_pointer)

    state
    |> update_object_definition(%{
      object_definition |
      functions: Map.put(object_definition.functions, function_definition.identifier, function_definition)
    })
  end

  defp update_object_definition(state, object_definition) do
    %{
      state |
      object_table: Map.put(state.object_table, object_definition.identifier, object_definition),
      defined_object_pointer: object_definition.identifier
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

    # Interpret the current AST to define all the objects.
    interpret(vm.ast, vm_pid)

    # Then, use the last defined Object's main function as the entrypoint.
    last_object = vm_pid |> Vape.VM.Process.lookup_current_object_definition()

    # [temporary]
    # simple check if main function exists.

    entry_point = last_object.functions["main"]
    if entry_point do
      interpret(entry_point.ast, vm_pid)
    else
      raise "No main() function was found."
    end
  end

  def interpret(ast, vm_pid) when is_list(ast) and is_pid(vm_pid) do
    Enum.map(ast, &(interpret(&1, vm_pid)))
  end

  def interpret({:import, _, _dotted_identifier}, _vm_pid) do
  end

  def interpret({:object, _, {:identifier, _, identifier}, body}, vm_pid) do
    # [temporary]
    # @todo(vy) Check all instance variables and put them in here.
    object_definition = %Vape.ObjectDefinition{
      identifier: to_string(identifier)
    }

    vm_pid |> Vape.VM.Process.define_object(object_definition)

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

  def interpret({:functiondef, _, {:identifier, _, identifier}, {params, body}}, vm_pid) do
    # [temporary]
    # if main() is defined, immediately execute.
    # case to_string(identifier) do
    #   "main" -> interpret(body, vm_pid)
    #   _ -> vm_pid |> Vape.VM.Process.define_in_scope(to_string(identifier), body)
    # end

    function_definition = %Vape.FunctionDefinition{
      identifier: to_string(identifier),
      arity: Enum.count(params),
      parameters: params,
      ast: body
    }

    vm_pid |> Vape.VM.Process.define_function(function_definition)
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
