defmodule Accounting.Adapter do
  alias Accounting.{Account, LineItem}

  @callback fetch_accounts([Account.no], timeout) :: {:ok, %{optional(Account.no) => Account.t}} | {:error, term}
  @callback record_entry(String.t, Date.t, [LineItem.t], timeout) :: :ok | {:error, term}
  @callback register_account(Account.no, String.t, timeout) :: :ok | {:error, term}
  @callback register_categories([atom], timeout) :: :ok | {:error, term}
  @callback start_link(opts :: any) :: Supervisor.on_start
end
