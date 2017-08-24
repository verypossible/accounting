defmodule Accounting.Account do
  @moduledoc """
  An account data structure and functions.
  """

  alias Accounting.AccountTransaction

  @opaque t :: %__MODULE__{number: account_number, transactions: [AccountTransaction.t]}

  @typep account_number :: Accounting.account_number

  defstruct [:number, {:transactions, []}]

  @spec average_daily_balance(t, Date.Range.t) :: integer
  def average_daily_balance(%__MODULE__{} = account, %Date.Range{} = date_range) do
    account
    |> Map.fetch!(:transactions)
    |> daily_balances(date_range)
    |> mean()
    |> round()
  end

  @spec daily_balances([AccountTransaction.t], Date.Range.t) :: [integer]
  defp daily_balances(transactions, date_range) do
    {_, {last_date, balances}} =
      Enumerable.reduce transactions, {:cont, {date_range.first, [0]}}, fn
        txn, {last_date, acc} ->
          cond do
            Date.diff(txn.date, date_range.last) > 0 ->
              {:halt, {last_date, acc}}
            Date.diff(txn.date, date_range.first) <= 0 or txn.date === last_date ->
              {:cont, {last_date, [hd(acc) + txn.amount|tl(acc)]}}
            true ->
              days = Date.diff(txn.date, last_date) - 1
              {:cont, {txn.date, [hd(acc) + txn.amount|repeat_head(acc, days)]}}
          end
      end

    balances
    |> repeat_head(Date.diff(date_range.last, last_date))
    |> Enum.reverse()
  end

  @spec repeat_head([integer], integer) :: [integer]
  defp repeat_head([head|_] = list, times) when times > 0 do
    Enum.reduce(1..times, list, fn _, acc -> [head|acc] end)
  end
  defp repeat_head(list, _), do: list

  @spec mean([integer]) :: float
  defp mean(list), do: Enum.reduce(list, 0, &Kernel.+/2) / length(list)

  @spec balance(t) :: integer
  def balance(%__MODULE__{} = account) do
    Enum.reduce(account.transactions, 0, & &1.amount + &2)
  end

  @spec balance_on_date(t, Date.t) :: integer
  def balance_on_date(%__MODULE__{} = account, %Date{} = date) do
    {_, balance} =
      Enumerable.reduce account.transactions, {:cont, 0}, fn transaction, acc ->
        if Date.compare(transaction.date, date) === :gt do
          {:halt, acc}
        else
          {:cont, acc + transaction.amount}
        end
      end

    balance
  end

  @spec transactions(t) :: [AccountTransaction.t]
  def transactions(%__MODULE__{} = account), do: account.transactions

  defimpl Inspect do
    import Inspect.Algebra, only: [concat: 1]

    def inspect(%{number: number}, _opts) do
      concat ["#Account<", number, ">"]
    end
  end
end
