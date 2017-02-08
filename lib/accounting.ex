defmodule Accounting do
  import Accounting.Helpers, only: [
    calculate_ADB!: 3,
    calculate_balance: 1,
    calculate_balance!: 2,
    sort_transactions: 1,
  ]

  def register_categories(categories) do
    adapter().register_categories(categories)
  end

  def create_account(number), do: adapter().create_account(number)

  def receive_money(from, date, line_items) do
    adapter().receive_money(from, date, line_items)
  end

  def fetch_account_transactions(account_number) do
    with {:ok, txns} <- adapter().fetch_account_transactions(account_number) do
      {:ok, sort_transactions(txns)}
    end
  end

  def fetch_balance(account_number) do
    with {:ok, txns} <- adapter().fetch_account_transactions(account_number) do
      {:ok, calculate_balance(txns)}
    end
  end

  def fetch_balance(account_number, date) do
    with {:ok, transactions} <- fetch_account_transactions(account_number) do
      {:ok, calculate_balance!(transactions, date)}
    end
  end

  def fetch_ADB(account_number, start_date, end_date) do
    with {:ok, transactions} <- fetch_account_transactions(account_number) do
      {:ok, calculate_ADB!(transactions, start_date, end_date)}
    end
  end

  defp adapter, do: Application.fetch_env!(:accounting, :adapter)
end
