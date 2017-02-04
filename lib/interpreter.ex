defmodule Vape.VM.ReferenceCounter do
  @moduledoc """
  Keeps track of objects and their associated reference count
  so it can be garbage collected with its refc == 0.
  """

  defstruct reference_counter: %{}
end

defmodule Vape.Object do
  @moduledoc """
  This struct defines an Object.
  """

  defstruct [
    identifier: nil,
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

defmodule Vape.VM.ObjectTable do
  defstruct objects: %{}, id_counter: -1
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

    # Holds instantiated Objects.
    object_table: %Vape.VM.ObjectTable{},

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
  def define_object(pid, %Vape.Object{} = object_definition) do
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
  Returns an Object if it exists currently within our object
  table.

  Otherwise, it means the identifier in question does not reference a
  defined Object.
  """
  def lookup_object_definition(pid, identifier) do
    pid |> GenServer.call({:lookup_object_definition, identifier})
  end

  @doc """
  Return current Object, using the VM's current `defined_object_pointer`.
  """
  def lookup_current_object_definition(pid) do
    pid |> GenServer.call(:lookup_current_object_definition)
  end

  @doc """
  Given an Object, instantiates an object from that definition
  and returns an object identifier to that new instance.

  This instantiated object is then stored in the VM's memory space.
  """
  @spec instantiate_object(pid(), String.t) :: {:ok, {:object, non_neg_integer()}} | {:error, :undefined_object}
  def instantiate_object(pid, identifier) do
    pid |> GenServer.call({:instantiate_object, identifier})
  end

  def enter_object(pid, object_instance_id) do
    pid |> GenServer.cast({:enter_object, object_instance_id})
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

  def handle_cast({:enter_object, object_instance_id}, state) do
    {:noreply, Map.put(state, :object_pointer, object_instance_id)}
  end

  def handle_call({:lookup_object_definition, identifier}, _from, state) do
    {:reply, Map.get(state.object_table.objects, identifier), state}
  end

  def handle_call(:lookup_current_object_definition, _from, state) do
    {:reply, Map.get(state.object_table.objects, state.defined_object_pointer), state}
  end

  # Create a %Vape.Object{} and put it in VM object_table.
  # Return that object's unique identifier.
  def handle_call({:instantiate_object, identifier}, _from, state) do
    object_instance = %Vape.Object{
      identifier: state.object_table.id_counter + 1
    }

    new_state = %{
      state |
      object_table: %{
        state.object_table |
        id_counter: object_instance.identifier,
        objects: Map.put(state.object_table.objects, object_instance.identifier, object_instance)
       }
    }

    {:reply, {:object, identifier, object_instance.identifier}, new_state}
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
    object_definition = Map.get(state.object_table.objects, state.defined_object_pointer)

    state
    |> update_object_definition(%{
      object_definition |
      functions: Map.put(object_definition.functions, function_definition.identifier, function_definition)
    })
  end

  defp update_object_definition(state, object_definition) do
    %{
      state |
      object_table: %{
        state.object_table |
        objects: Map.put(state.object_table.objects, object_definition.identifier, object_definition),
      },
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

    # Get the last object defined, and instantiate it.
    last_object = vm_pid |> Vape.VM.Process.lookup_current_object_definition()
    main_object_instance = vm_pid |> Vape.VM.Process.instantiate_object(last_object.identifier)

    # Enter instantiated object scope.
    vm_pid |> Vape.VM.Process.enter_object(main_object_instance)
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
    object_definition = %Vape.Object{
      identifier: to_string(identifier)
    }

    vm_pid |> Vape.VM.Process.define_object(object_definition)

    Enum.map(body, &(interpret(&1, vm_pid)))
  end

  def interpret({:declaration, _, body}, vm_pid) do
    Enum.map(body, &(interpret(&1, vm_pid)))
  end

  def interpret({:assign, _, {:identifier, _, identifier}, rhs_exp}, vm_pid) do
    value = interpret(rhs_exp, vm_pid)
    vm_pid |> Vape.VM.Process.define_in_scope(to_string(identifier), value)
  end

  def interpret({:functiondef, _, {:identifier, _, identifier}, {params, body}}, vm_pid) do
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
        interpret(param, vm_pid)
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
    lhs = interpret(lhs_exp, vm_pid)
    rhs = interpret(rhs_exp, vm_pid)

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

  def interpret({:identifier, _, dotted_identifiers} = identifier, vm_pid) when is_list(dotted_identifiers) do
    vm_pid |> Vape.VM.Process.lookup_in_scope(join_dotted_identifier(identifier))
  end

  def interpret({:identifier, _, identifier}, vm_pid) do
    vm_pid |> Vape.VM.Process.lookup_in_scope(identifier)
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
