defmodule Accounting.AccountTransaction do
  @moduledoc """
  An account transaction struct.
  """

  @type t :: %__MODULE__{}

  defstruct [:amount, :description, :date]
end
