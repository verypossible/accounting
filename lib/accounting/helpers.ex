defmodule Accounting.Helpers do
  @moduledoc false

  @spec calculate_balance([AccountTransaction.t]) :: integer
  def calculate_balance(account_transactions) do
    Enum.reduce(account_transactions, 0, & &1.amount + &2)
  end

  @spec calculate_balance!([AccountTransaction.t], Date.t) :: integer | no_return
  def calculate_balance!(account_transactions, date) do
    if sorted?(account_transactions) do
      do_calculate_balance(account_transactions, date)
    else
      raise ArgumentError, message: "Account transactions are unsorted"
    end
  end

  @spec do_calculate_balance([AccountTransaction.t], Date.t) :: integer
  defp do_calculate_balance(transactions, date) do
    {_, balance} =
      Enumerable.reduce transactions, {:cont, 0}, fn transaction, acc ->
        if diff(transaction.date, date) > 0 do
          {:halt, acc}
        else
          {:cont, acc + transaction.amount}
        end
      end

    balance
  end

  @spec calculate_ADB!([AccountTransaction.t], Date.t, Date.t) :: integer | no_return
  def calculate_ADB!(account_transactions, start_date, end_date) do
    if sorted?(account_transactions) do
      account_transactions
      |> daily_balances(start_date, end_date)
      |> mean()
      |> round()
    else
      raise ArgumentError, message: "Account transactions are unsorted"
    end
  end

  @spec sorted?([AccountTransaction.t]) :: boolean
  defp sorted?(transactions) do
    {result, _} =
      Enumerable.reduce transactions, {:cont, ~D[0000-01-01]}, fn
        txn, last_date ->
          if diff(txn.date, last_date) < 0 do
            {:halt, txn.date}
          else
            {:cont, txn.date}
          end
      end

    result === :done
  end

  @spec sort_transactions([AccountTransaction.t]) :: [AccountTransaction.t]
  def sort_transactions(transactions) do
    Enum.sort(transactions, & diff(&1.date, &2.date) <= 0)
  end

  @spec daily_balances([AccountTransaction.t], Date.t, Date.t) :: [integer]
  defp daily_balances(transactions, start_date, end_date) do
    {_, {last_date, balances}} =
      Enumerable.reduce transactions, {:cont, {start_date, [0]}}, fn
        txn, {last_date, acc} ->
          cond do
            diff(txn.date, end_date) > 0 ->
              {:halt, {last_date, acc}}
            diff(txn.date, start_date) <= 0 or txn.date === last_date ->
              {:cont, {last_date, [hd(acc) + txn.amount|tl(acc)]}}
            true ->
              days = diff(txn.date, last_date) - 1
              {:cont, {txn.date, [hd(acc) + txn.amount|repeat_head(acc, days)]}}
          end
      end

    balances
    |> repeat_head(diff(end_date, last_date))
    |> Enum.reverse()
  end

  @spec diff(Date.t, Date.t) :: -30..30
  defp diff(start_date, end_date) do
    to_gregorian_days(start_date) - to_gregorian_days(end_date)
  end

  @spec to_gregorian_days(Date.t) :: 1..31
  defp to_gregorian_days(date) do
    date
    |> Date.to_erl()
    |> :calendar.date_to_gregorian_days()
  end

  @spec repeat_head([integer], integer) :: [integer]
  defp repeat_head([hd|_] = list, times) when times > 0 do
    Enum.reduce(1..times, list, fn _, acc -> [hd|acc] end)
  end
  defp repeat_head(list, _), do: list

  @spec mean([integer]) :: float
  defp mean(list), do: Enum.reduce(list, 0, &Kernel.+/2) / length(list)
end
