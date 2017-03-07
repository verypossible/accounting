defmodule Accounting.LineItem do
  @type t :: %Accounting.LineItem{}

  defstruct [:description, :amount, :account_number, category: :other]
end
