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
