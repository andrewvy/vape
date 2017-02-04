defmodule Vape.VM.ReferenceCounter do
  @moduledoc """
  Keeps track of objects and their associated reference count
  so it can be garbage collected with its refc == 0.
  """

  defstruct reference_counter: %{}
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

defmodule Vape.VM.Utils do
  def init(vm \\ %Vape.VM{}) do
    Process.put(:vm, vm)
  end

  @doc """
  Defines a variable within the current stackframe, as indicated by
  the VM's stack pointer.
  """
  def define_in_scope(identifier, value) do
    vm = Process.get(:vm)

    Process.put(:vm,
     %{
        vm |
        stackframes: List.update_at(vm.stackframes, vm.stack_pointer, fn(old_frame) ->
          Map.put(old_frame, identifier, value)
        end)
      }
    )
  end

  @doc """
  Look up a variable name within the current stackframe, as indicated
  by the VM's stack pointer.

  Given an identifier, looks up within the current stackframe to find
  that variable.

  Else, if that variable does not exist within the current stackframe,
  check if the current object has the variable.

  See https://github.com/andrewvy/vape/issues/2 for scope rules.
  """
  def lookup_in_scope(identifier) do
    vm = Process.get(:vm)
    stackframe = Enum.at(vm.stackframes, vm.stack_pointer)
    Map.get(stackframe, identifier)
  end

  @doc """
  Defines an object, this will put the object within our object table
  with its identifier and associated object definition.

  This object definition will contain its functions AST, as well as its
  exported functions and instance variables.
  """
  def define_object(%Vape.Object{} = object_definition) do
    update_object_definition(object_definition)
  end

  @doc """
  Defines a function, this will put the function definition into the
  current object, using the VM's current `defined_object_pointer`.
  """
  def define_function(%Vape.Function{} = function_definition) do
    define_function_in_object(function_definition)
  end

  @doc """
  Returns an Object if it exists currently within our object
  table.

  Otherwise, it means the identifier in question does not reference a
  defined Object.
  """
  def lookup_object_definition(identifier) do
    vm = Process.get(:vm)
    Map.get(vm.object_table.objects, identifier)
  end

  @doc """
  Return current Object, using the VM's current `defined_object_pointer`.
  """
  def lookup_current_object_definition() do
    vm = Process.get(:vm)
    Map.get(vm.object_table.objects, vm.defined_object_pointer)
  end

  @doc """
  Given an Object, instantiates an object from that definition
  and returns an object identifier to that new instance.

  This instantiated object is then stored in the VM's memory space.
  """
  @spec instantiate_object(String.t) :: {:ok, {:object, non_neg_integer()}} | {:error, :undefined_object}
  def instantiate_object(identifier) do
    vm = Process.get(:vm)

    object_instance = %Vape.Object{
      identifier: vm.object_table.id_counter + 1
    }

    new_vm = %{
      vm |
      object_table: %{
        vm.object_table |
        id_counter: object_instance.identifier,
        objects: Map.put(vm.object_table.objects, object_instance.identifier, object_instance)
       }
    }

    Process.put(:vm, new_vm)

    {:object, identifier, object_instance.identifier}
  end

  def enter_object(object_instance_id) do
    vm = Process.get(:vm)

    Process.put(:vm,
     %{
       vm |
       object_pointer: object_instance_id
     }
   )
  end

  @doc """
  [debug]

  Internal debug function to dump all the stackframes of the VM process.
  """
  def get_stack_frames() do
    vm = Process.get(:vm)
    vm.stackframes
  end

  defp define_function_in_object(function_definition) do
    vm = Process.get(:vm)
    object_definition = Map.get(vm.object_table.objects, vm.defined_object_pointer)

    update_object_definition(%{
      object_definition |
      functions: Map.put(object_definition.functions, function_definition.identifier, function_definition)
    })
  end

  defp update_object_definition(object_definition) do
    vm = Process.get(:vm)
    Process.put(:vm,
      %{
        vm |
        object_table: %{
          vm.object_table |
          objects: Map.put(vm.object_table.objects, object_definition.identifier, object_definition),
        },
        defined_object_pointer: object_definition.identifier
      }
    )
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
    Vape.VM.Utils.init(vm)

    # Interpret the current AST to define all the objects.
    interpret(vm.ast)

    # Get the last object defined, and instantiate it.
    last_object = Vape.VM.Utils.lookup_current_object_definition()
    main_object_instance = Vape.VM.Utils.instantiate_object(last_object.identifier)

    # Enter instantiated object scope.
    Vape.VM.Utils.enter_object(main_object_instance)
    entry_point = last_object.functions["main"]

    if entry_point do
      interpret(entry_point.ast)
    else
      raise "No main() function was found."
    end
  end

  def interpret(ast) when is_list(ast) do
    Enum.map(ast, &(interpret(&1)))
  end

  def interpret({:import, _, _dotted_identifier}) do
  end

  def interpret({:object, _, {:identifier, _, identifier}, body}) do
    # [temporary]
    # @todo(vy) Check all instance variables and put them in here.
    object_definition = %Vape.Object{
      identifier: to_string(identifier)
    }

    Vape.VM.Utils.define_object(object_definition)

    Enum.map(body, &(interpret(&1)))
  end

  def interpret({:declaration, _, body}) do
    Enum.map(body, &(interpret(&1)))
  end

  def interpret({:assign, _, {:identifier, _, identifier}, rhs_exp}) do
    value = interpret(rhs_exp)
    Vape.VM.Utils.define_in_scope(to_string(identifier), value)
  end

  def interpret({:functiondef, _, {:identifier, _, identifier}, {params, body}}) do
    function_definition = %Vape.Function{
      identifier: to_string(identifier),
      arity: Enum.count(params),
      parameters: params,
      ast: body
    }

    Vape.VM.Utils.define_function(function_definition)
  end

  def interpret({:functioncall, _, dotted_identifier, params}) do
    joined_identifier = join_dotted_identifier(dotted_identifier)

    if Map.has_key?(@temporary_functions, joined_identifier) do
      {func_arity, func} = @temporary_functions[joined_identifier]

      values = Enum.map(params, fn(param) ->
        interpret(param)
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

  def interpret({:op, _line, operation, lhs_exp, rhs_exp}) do
    lhs = interpret(lhs_exp)
    rhs = interpret(rhs_exp)

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

  def interpret({:identifier, _, dotted_identifiers} = identifier) when is_list(dotted_identifiers) do
    Vape.VM.Utils.lookup_in_scope(join_dotted_identifier(identifier))
  end

  def interpret({:identifier, _, identifier}) do
    Vape.VM.Utils.lookup_in_scope(identifier)
  end

  def interpret({type, _, value}) when type in @types do
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
