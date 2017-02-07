defmodule Accounting.LineItem do
  defstruct [:description, :amount, :account_number, category: :other]
end
