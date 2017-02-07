defmodule Accounting.Adapter do
  @callback start_link() :: Supervisor.on_start
  @callback register_categories(list(atom)) :: :ok | {:error, any}
  @callback create_account(binary) :: :ok | {:error, any}
  @callback receive_money(binary, Date.t, list(Accounting.LineItem.t)) :: :ok | {:error, any}
  @callback fetch_account_transactions(binary) :: {:ok, list(Accounting.AccountTransaction.t)} | {:error, any}
end
