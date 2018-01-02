defmodule Accounting.Adapter do
  @moduledoc """
  A behaviour module for implementing the adapter for a particular journal.
  """

  alias Accounting.{Account, Entry, Journal}

  @typep account_number :: Accounting.account_number

  @callback child_spec(keyword) :: Supervisor.child_spec
  @callback setup_accounts(Journal.id, [Account.setup, ...], timeout) :: :ok | {:error, term}
  @callback setup_account_conversions(Journal.id, 1..12, pos_integer, [Account.setup, ...], timeout) :: :ok | {:error, term}
  @callback list_accounts(Journal.id, timeout) :: {:ok, [account_number]} | {:error, term}
  @callback fetch_accounts(Journal.id, [account_number], timeout) :: {:ok, Journal.accounts} | {:error, term}
  @callback record_entries(Journal.id, [Entry.t, ...], timeout) :: :ok | {:error, [Entry.Error.t] | term}
  @callback record_invoices(Journal.id, [Entry.t, ...], timeout) :: :ok | {:error, [Entry.Error.t] | term}
  @callback register_account(Journal.id, account_number, String.t, timeout) :: :ok | {:error, term}
  @callback register_categories(Journal.id, [atom], timeout) :: :ok | {:error, term}
  @callback start_link(opts :: any) :: Supervisor.on_start
end
