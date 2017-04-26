defmodule Accounting.AccountTransaction do
  @type t :: %__MODULE__{}

  defstruct [:amount, :description, :date]
end
