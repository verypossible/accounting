defmodule Accounting.Journal do
  @moduledoc """
  Functions that write to and read from the journal.
  """

  alias Accounting.{Account, LineItem}

  @default_timeout 5_000

  @spec fetch_accounts([Account.no], timeout) :: {:ok, %{optional(Account.no) => Account.t}} | {:error, term}
  def fetch_accounts(numbers, timeout \\ @default_timeout) do
    adapter().fetch_accounts(numbers, timeout)
  end

  @spec record_entry(String.t, Date.t, [LineItem.t], timeout) :: :ok | {:error, term}
  def record_entry(party, date, line_items, timeout \\ @default_timeout) do
    filtered_line_items = for i <- line_items, i.amount !== 0, do: i
    adapter().record_entry(party, date, filtered_line_items, timeout)
  end

  @spec register_account(Account.no, String.t, timeout) :: :ok | {:error, term}
  def register_account(number, description, timeout \\ @default_timeout) do
    adapter().register_account(number, description, timeout)
  end

  @spec register_categories([atom], timeout) :: :ok | {:error, term}
  def register_categories(categories, timeout \\ @default_timeout) do
    adapter().register_categories(categories, timeout)
  end

  @spec adapter() :: module
  defp adapter, do: Agent.get(__MODULE__, & &1)
end
