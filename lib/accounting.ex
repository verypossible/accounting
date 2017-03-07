defmodule Accounting do
  import Accounting.Helpers, only: [
    calculate_ADB!: 3,
    calculate_balance: 1,
    calculate_balance!: 2,
    sort_transactions: 1,
  ]

  @spec register_categories(list(atom)) :: :ok | {:error, any}
  def register_categories(categories) do
    adapter().register_categories(categories)
  end

  @spec create_account(binary) :: :ok | {:error, any}
  def create_account(number), do: adapter().create_account(number)

  @spec receive_money(binary, Date.t, list(Accounting.LineItem.t)) :: :ok | {:error, any}
  def receive_money(from, date, line_items) do
    adapter().receive_money(from, date, filter_line_items(line_items))
  end

  @spec spend_money(binary, Date.t, list(Accounting.LineItem.t)) :: :ok | {:error, any}
  def spend_money(to, date, line_items) do
    adapter().spend_money(to, date, filter_line_items(line_items))
  end

  defp filter_line_items(line_items) do
    for i <- line_items, i.amount !== 0, do: i
  end

  @spec fetch_account_transactions(binary) :: {:ok, list(Accounting.AccountTransaction.t)} | {:error, any}
  def fetch_account_transactions(account_number) do
    with {:ok, txns} <- adapter().fetch_account_transactions(account_number) do
      {:ok, sort_transactions(txns)}
    end
  end

  @spec fetch_balance(binary) :: {:ok, integer} | {:error, any}
  def fetch_balance(account_number) do
    with {:ok, txns} <- adapter().fetch_account_transactions(account_number) do
      {:ok, calculate_balance(txns)}
    end
  end

  @spec fetch_balance(binary, Date.t) :: {:ok, integer} | {:error, any}
  def fetch_balance(account_number, date) do
    with {:ok, transactions} <- fetch_account_transactions(account_number) do
      {:ok, calculate_balance!(transactions, date)}
    end
  end

  @spec fetch_ADB(binary, Date.t, Date.t) :: {:ok, integer} | {:error, any}
  def fetch_ADB(account_number, start_date, end_date) do
    with {:ok, transactions} <- fetch_account_transactions(account_number) do
      {:ok, calculate_ADB!(transactions, start_date, end_date)}
    end
  end

  defp adapter, do: Application.fetch_env!(:accounting, :adapter)
end
