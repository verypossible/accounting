defmodule Accounting.AccountTransaction do
  @type t :: %Accounting.AccountTransaction{}

  defstruct [:amount, :description, :date]
end
