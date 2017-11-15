defmodule Accounting.Journal do
  @moduledoc """
  Functions that write to and read from the journal.
  """

  alias Accounting.{Account, Journal, LineItem}

  @type accounts :: %{optional(account_number) => Account.t}
  @type id :: atom

  @typep account_number :: Accounting.account_number

  @default_timeout 5_000

  @spec child_spec(keyword) :: Supervisor.child_spec
  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}}
  end

  @spec fetch_accounts(Journal.id, [account_number], timeout) :: {:ok, accounts} | {:error, term}
  def fetch_accounts(journal_id, numbers, timeout \\ @default_timeout) do
    adapter().fetch_accounts(journal_id, numbers, timeout)
  end

  @spec record_entry(Journal.id, String.t, Date.t, [LineItem.t], timeout) :: :ok | {:error, term}
  def record_entry(journal_id, party, date, line_items, timeout \\ @default_timeout) do
    filtered = for i <- line_items, i.amount !== 0, do: i
    adapter().record_entry(journal_id, party, date, filtered, timeout)
  end

  @spec register_account(Journal.id, account_number, String.t, timeout) :: :ok | {:error, term}
  def register_account(journal_id, number, description, timeout \\ @default_timeout) do
    adapter().register_account(journal_id, number, description, timeout)
  end

  @spec register_categories(Journal.id, [atom], timeout) :: :ok | {:error, term}
  def register_categories(journal_id, categories, timeout \\ @default_timeout) do
    adapter().register_categories(journal_id, categories, timeout)
  end

  @spec adapter() :: module
  defp adapter, do: Agent.get(__MODULE__, & &1)

  @spec start_link(keyword) :: Supervisor.on_start
  def start_link(opts) do
    adapter = Keyword.fetch!(opts, :adapter)
    journal_opts = Keyword.get(opts, :journal_opts, %{})
    agent_spec = %{
      id: Agent,
      start: {Agent, :start_link, [fn -> adapter end, [name: __MODULE__]]},
    }
    children = [
      agent_spec,
      {adapter, journal_opts},
    ]
    Supervisor.start_link children,
      name: Accounting.Supervisor,
      strategy: :one_for_all
  end
end
