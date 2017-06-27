defmodule Accounting.Adapter do
  @callback create_account(String.t, String.t, timeout) :: :ok | {:error, term}
  @callback fetch_account_transactions(String.t, timeout) :: {:ok, [Accounting.AccountTransaction.t]} | {:error, term}
  @callback register_categories([atom], timeout) :: :ok | {:error, term}
  @callback start_link(opts :: any) :: Supervisor.on_start
  @callback transact(String.t, Date.t, [Accounting.LineItem.t], timeout) :: :ok | {:error, term}
end
