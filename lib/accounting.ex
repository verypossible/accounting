defmodule Accounting do
  import Accounting.Helpers, only: [
    calculate_ADB!: 3,
    calculate_balance: 1,
    calculate_balance!: 2,
    sort_transactions: 1,
  ]

  @default_timeout 5_000

  @spec start_link(keyword) :: Supervisor.on_start
  def start_link(opts) do
    import Supervisor.Spec, warn: false

    adapter = Keyword.fetch!(opts, :adapter)
    children = [
      worker(Agent, [fn -> adapter end, [name: __MODULE__]]),
      worker(adapter, [opts]),
    ]
    Supervisor.start_link children,
      name: Accounting.Supervisor,
      strategy: :one_for_all
  end

  @spec create_account(String.t, String.t, timeout) :: :ok | {:error, term}
  def create_account(number, description, timeout \\ @default_timeout) do
    adapter().create_account(number, description, timeout)
  end

  @spec fetch_account_transactions(String.t, timeout) :: {:ok, [Accounting.AccountTransaction.t]} | {:error, term}
  def fetch_account_transactions(account_number, timeout \\ @default_timeout) do
    response = adapter().fetch_account_transactions(account_number, timeout)
    with {:ok, txns} <- response, do: {:ok, sort_transactions(txns)}
  end

  @spec fetch_ADB(String.t, Date.t, Date.t, timeout) :: {:ok, integer} | {:error, term}
  def fetch_ADB(account_number, start_date, end_date, timeout \\ @default_timeout) do
    response = fetch_account_transactions(account_number, timeout)
    with {:ok, transactions} <- response do
      {:ok, calculate_ADB!(transactions, start_date, end_date)}
    end
  end

  @spec fetch_balance(String.t, timeout) :: {:ok, integer} | {:error, term}
  def fetch_balance(account_number, timeout \\ @default_timeout) do
    response = adapter().fetch_account_transactions(account_number, timeout)
    with {:ok, txns} <- response, do: {:ok, calculate_balance(txns)}
  end

  @spec fetch_balance_on_date(String.t, Date.t, timeout) :: {:ok, integer} | {:error, term}
  def fetch_balance_on_date(account_number, date, timeout \\ @default_timeout) do
    response = fetch_account_transactions(account_number, timeout)
    with {:ok, transactions} <- response do
      {:ok, calculate_balance!(transactions, date)}
    end
  end

  @spec register_categories([atom], timeout) :: :ok | {:error, term}
  def register_categories(categories, timeout \\ @default_timeout) do
    adapter().register_categories(categories, timeout)
  end

  @spec transact(String.t, Date.t, [Accounting.LineItem.t], timeout) :: :ok | {:error, term}
  def transact(party, date, line_items, timeout \\ @default_timeout) do
    adapter().transact(party, date, filter_line_items(line_items), timeout)
  end

  @spec filter_line_items([Accounting.LineItem.t]) :: [Accounting.LineItem.t]
  defp filter_line_items(line_items) do
    for i <- line_items, i.amount !== 0, do: i
  end

  @spec adapter() :: module
  defp adapter, do: Agent.get(__MODULE__, & &1)
end
