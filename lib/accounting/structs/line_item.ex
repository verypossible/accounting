defmodule Accounting.LineItem do
  @type t :: %__MODULE__{}

  defstruct [:description, :amount, :account_number, category: :other]
end
