defmodule Accounting.TestAdapter do
  @moduledoc """
  The journal adapter for test.
  """

  alias Accounting.{
    Account,
    AccountTransaction,
    Adapter,
    Entry,
    Helpers,
    Journal,
  }
  import Helpers, only: [sort_transactions: 1]

  @behaviour Adapter

  @typep account_number :: Accounting.account_number
  @typep state :: %{optional(Journal.id) => transactions}
  @typep transactions :: %{optional(account_number) => [AccountTransaction.t]}

  @impl Adapter
  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}}
  end

  @impl Adapter
  def setup_accounts(journal_id, accounts, _timeout) do
    send self(), {:setup_accounts, journal_id, accounts}

    Agent.update(__MODULE__, fn(state) ->
      journal_state = Enum.reduce(accounts, %{}, fn(account, acc) ->
        Map.put(acc, account.number, [])
      end)

      Map.put(state, journal_id, journal_state)
    end)
  end

  @impl Adapter
  def list_accounts(journal_id, _timeout) do
    accounts = Agent.get(__MODULE__, fn(state) ->
      state
      |> Map.get(journal_id, %{})
      |> Map.keys()
    end)

    {:ok, accounts}
  end

  @impl Adapter
  def fetch_accounts(journal_id, numbers, _timeout) do
    {:ok, Agent.get(__MODULE__, &get_accounts(&1, journal_id, numbers))}
  end

  @impl Adapter
  def register_account(journal_id, number, _description, _timeout) do
    send self(), {:registered_account, journal_id, number}

    if exists?(journal_id, number) do
      {:error, :duplicate}
    else
      Agent.update(__MODULE__, &put_account(&1, journal_id, number))
    end
  end

  @spec get_accounts(state, Journal.id, [account_number]) :: Journal.accounts
  defp get_accounts(state, journal_id, numbers) do
    for number <- numbers, into: %{} do
      account =
        if acct_txns = state[journal_id][number] do
          %Account{number: number, transactions: sort_transactions(acct_txns)}
        else
          %Account{number: number}
        end

      {number, account}
    end
  end

  @impl Adapter
  def record_entries(journal_id, entries, _timeout) do
    send self(), {:recorded_entries, journal_id, entries}
    Enum.reduce_while entries, :ok, fn e, _ ->
      case record_entry(journal_id, e) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end
  end

  @spec record_entry(Journal.id, Entry.t) :: :ok | {:error, :no_such_account}
  defp record_entry(journal_id, entry) do
    %Entry{
      date: %Date{} = date,
      line_items: [_|_] = line_items,
      party: <<_::binary>>,
    } = entry

    if all_exist?(journal_id, (for i <- line_items, do: i.account_number)) do
      Agent.update __MODULE__, fn state ->
        transactions = state[journal_id] || %{}
        new_transactions =
          Enum.reduce line_items, transactions, fn item, acc ->
            transaction = %AccountTransaction{
              amount: item.amount,
              description: item.description,
              date: date,
            }
            Map.update!(acc, item.account_number, &[transaction|&1])
          end

        Map.put(state, journal_id, new_transactions)
      end
    else
      {:error, :no_such_account}
    end
  end

  @spec all_exist?(Journal.id, [account_number]) :: boolean
  defp all_exist?(journal_id, account_numbers) do
    Agent.get __MODULE__, fn state ->
      Enum.all?(account_numbers, &Map.has_key?(state[journal_id] || %{}, &1))
    end
  end

  @spec put_account(state, Journal.id, account_number) :: state
  defp put_account(state, journal_id, number) do
    Map.update state, journal_id, %{number => []}, fn transactions ->
      Map.put(transactions, number, [])
    end
  end

  @spec exists?(Journal.id, account_number) :: boolean
  defp exists?(journal_id, account_number) do
    Agent.get(__MODULE__, &Map.has_key?(&1[journal_id] || %{}, account_number))
  end

  @impl Adapter
  def register_categories(journal_id, categories, _timeout) do
    send self(), {:registered_categories, journal_id, categories}
    :ok
  end

  @spec reset() :: :ok
  def reset, do: Agent.update(__MODULE__, fn _ -> %{} end)

  @impl Adapter
  def start_link(_opts), do: Agent.start_link(&Map.new/0, name: __MODULE__)
end
