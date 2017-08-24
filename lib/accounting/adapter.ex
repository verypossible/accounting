defmodule Accounting.Adapter do
  alias Accounting.{Journal, LineItem}

  @typep account_number :: Accounting.account_number

  @callback child_spec(keyword) :: Supervisor.Spec.spec
  @callback fetch_accounts([account_number], timeout) :: {:ok, Journal.accounts} | {:error, term}
  @callback record_entry(String.t, Date.t, [LineItem.t], timeout) :: :ok | {:error, term}
  @callback register_account(account_number, String.t, timeout) :: :ok | {:error, term}
  @callback register_categories([atom], timeout) :: :ok | {:error, term}
  @callback start_link(opts :: any) :: Supervisor.on_start
end
