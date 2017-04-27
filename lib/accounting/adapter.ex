defmodule Accounting.Adapter do
  @callback create_account(String.t, String.t, timeout) :: :ok | {:error, term}
  @callback fetch_account_transactions(String.t, timeout) :: {:ok, [Accounting.AccountTransaction.t]} | {:error, term}
  @callback receive_money(String.t, Date.t, [Accounting.LineItem.t], timeout) :: :ok | {:error, term}
  @callback register_categories([atom], timeout) :: :ok | {:error, term}
  @callback spend_money(String.t, Date.t, [Accounting.LineItem.t], timeout) :: :ok | {:error, term}
  @callback start_link(opts :: any) :: Supervisor.on_start
end
