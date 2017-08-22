defmodule Accounting.Helpers do
  @moduledoc false

  alias Accounting.AccountTransaction

  @spec sort_transactions([AccountTransaction.t]) :: [AccountTransaction.t]
  def sort_transactions(transactions) do
    Enum.sort(transactions, & Date.diff(&1.date, &2.date) <= 0)
  end
end
