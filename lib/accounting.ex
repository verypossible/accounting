defmodule Accounting do
  import Accounting.Helpers, only: [
    calculate_ADB!: 3,
    calculate_balance: 1,
    calculate_balance!: 2,
    sort_transactions: 1,
  ]

  @default_timeout 5_000

  @spec register_categories([atom], timeout) :: :ok | {:error, any}
  def register_categories(categories, timeout \\ @default_timeout) do
    adapter().register_categories(categories, timeout)
  end

  @spec create_account(String.t, timeout) :: :ok | {:error, any}
  def create_account(number, timeout \\ @default_timeout), do: adapter().create_account(number, timeout)

  @spec receive_money(String.t, Date.t, [Accounting.LineItem.t], timeout) :: :ok | {:error, any}
  def receive_money(from, date, line_items, timeout \\ @default_timeout) do
    adapter().receive_money(from, date, filter_line_items(line_items), timeout)
  end

  @spec spend_money(String.t, Date.t, [Accounting.LineItem.t], timeout) :: :ok | {:error, any}
  def spend_money(to, date, line_items, timeout \\ @default_timeout) do
    adapter().spend_money(to, date, filter_line_items(line_items), timeout)
  end

  @spec filter_line_items([Accounting.LineItem.t]) :: [Accounting.LineItem.t]
  defp filter_line_items(line_items) do
    for i <- line_items, i.amount !== 0, do: i
  end

  @spec fetch_account_transactions(String.t, timeout) :: {:ok, [Accounting.AccountTransaction.t]} | {:error, any}
  def fetch_account_transactions(account_number, timeout \\ @default_timeout) do
    response = adapter().fetch_account_transactions(account_number, timeout)
    with {:ok, txns} <- response, do: {:ok, sort_transactions(txns)}
  end

  @spec fetch_balance(String.t, timeout) :: {:ok, integer} | {:error, any}
  def fetch_balance(account_number, timeout \\ @default_timeout) do
    response = adapter().fetch_account_transactions(account_number, timeout)
    with {:ok, txns} <- response, do: {:ok, calculate_balance(txns)}
  end

  @spec fetch_balance_on_date(String.t, Date.t, timeout) :: {:ok, integer} | {:error, any}
  def fetch_balance_on_date(account_number, date, timeout \\ @default_timeout) do
    response = fetch_account_transactions(account_number, timeout)
    with {:ok, transactions} <- response do
      {:ok, calculate_balance!(transactions, date)}
    end
  end

  @spec fetch_ADB(String.t, Date.t, Date.t, timeout) :: {:ok, integer} | {:error, any}
  def fetch_ADB(account_number, start_date, end_date, timeout \\ @default_timeout) do
    response = fetch_account_transactions(account_number, timeout)
    with {:ok, transactions} <- response do
      {:ok, calculate_ADB!(transactions, start_date, end_date)}
    end
  end

  @spec adapter() :: module
  defp adapter, do: Application.fetch_env!(:accounting, :adapter)
end
