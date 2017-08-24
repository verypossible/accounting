defmodule Accounting.Journal do
  @moduledoc """
  Functions that write to and read from the journal.
  """

  alias Accounting.{Account, LineItem}

  @type accounts :: %{optional(account_number) => Account.t}

  @typep account_number :: Accounting.account_number

  @default_timeout 5_000

  @spec child_spec(keyword) :: Supervisor.Spec.spec
  def child_spec(opts), do: Supervisor.Spec.worker(__MODULE__, [opts])

  @spec fetch_accounts([account_number], timeout) :: {:ok, accounts} | {:error, term}
  def fetch_accounts(numbers, timeout \\ @default_timeout) do
    adapter().fetch_accounts(numbers, timeout)
  end

  @spec record_entry(String.t, Date.t, [LineItem.t], timeout) :: :ok | {:error, term}
  def record_entry(party, date, line_items, timeout \\ @default_timeout) do
    filtered_line_items = for i <- line_items, i.amount !== 0, do: i
    adapter().record_entry(party, date, filtered_line_items, timeout)
  end

  @spec register_account(account_number, String.t, timeout) :: :ok | {:error, term}
  def register_account(number, description, timeout \\ @default_timeout) do
    adapter().register_account(number, description, timeout)
  end

  @spec register_categories([atom], timeout) :: :ok | {:error, term}
  def register_categories(categories, timeout \\ @default_timeout) do
    adapter().register_categories(categories, timeout)
  end

  @spec adapter() :: module
  defp adapter, do: Agent.get(__MODULE__, & &1)

  @spec start_link(keyword) :: Supervisor.on_start
  def start_link(opts) do
    adapter = Keyword.fetch!(opts, :adapter)
    children = [
      Supervisor.Spec.worker(Agent, [fn -> adapter end, [name: __MODULE__]]),
      {adapter, opts},
    ]
    Supervisor.start_link children,
      name: Accounting.Supervisor,
      strategy: :one_for_all
  end
end
