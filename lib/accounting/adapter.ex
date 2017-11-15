defmodule Accounting.Adapter do
  alias Accounting.{Journal, LineItem}

  @typep account_number :: Accounting.account_number

  @callback child_spec(keyword) :: Supervisor.child_spec
  @callback fetch_accounts(Journal.id, [account_number], timeout) :: {:ok, Journal.accounts} | {:error, term}
  @callback record_entry(Journal.id, String.t, Date.t, [LineItem.t], timeout) :: :ok | {:error, term}
  @callback register_account(Journal.id, account_number, String.t, timeout) :: :ok | {:error, term}
  @callback register_categories(Journal.id, [atom], timeout) :: :ok | {:error, term}
  @callback start_link(opts :: any) :: Supervisor.on_start
end
