defmodule Accounting.TestAdapter do
  alias Accounting.{Account, AccountTransaction, Adapter, Helpers}
  import Helpers, only: [sort_transactions: 1]

  @behaviour Adapter

  @typep transactions :: %{optional(String.t) => [AccountTransaction.t]}

  @impl Adapter
  def fetch_accounts(numbers, _timeout) do
    {:ok, Agent.get(__MODULE__, &get_accounts(&1, numbers))}
  end

  @spec get_accounts(transactions, [Account.no]) :: %{optional(Account.no) => Account.t}
  defp get_accounts(transactions, numbers) do
    for number <- numbers, into: %{} do
      account =
        if acct_txns = transactions[number] do
          %Account{number: number, transactions: sort_transactions(acct_txns)}
        else
          %Account{number: number}
        end

      {number, account}
    end
  end

  @impl Adapter
  def record_entry(<<_::binary>> = party, %Date{} = date, [_|_] = line_items, _timeout) do
    for item <- line_items, do: send self(), {:transaction, party, date, item}

    if all_exist?(for i <- line_items, do: i.account_number) do
      Agent.update __MODULE__, fn state ->
        Enum.reduce line_items, state, fn item, acc ->
          number = item.account_number
          transaction = %AccountTransaction{
            amount: item.amount,
            description: item.description,
            date: date,
          }
          Map.update!(acc, number, &List.insert_at(&1, 0, transaction))
        end
      end
    else
      {:error, :no_such_account}
    end
  end

  @spec all_exist?([String.t]) :: boolean
  defp all_exist?(account_numbers) do
    Agent.get __MODULE__, fn state ->
      Enum.all?(account_numbers, &Map.has_key?(state, &1))
    end
  end

  @impl Adapter
  def register_account(number, _description, _timeout) do
    send self(), {:created_account, number}

    if exists?(number) do
      {:error, :duplicate}
    else
      Agent.update(__MODULE__, &Map.put(&1, number, []))
    end
  end

  @spec exists?(String.t) :: boolean
  defp exists?(account_number) do
    Agent.get(__MODULE__, &Map.has_key?(&1, account_number))
  end

  @impl Adapter
  def register_categories(categories, _timeout) do
    for c <- categories, do: send self(), {:registered_category, c}
    :ok
  end

  @spec reset() :: :ok
  def reset, do: Agent.update(__MODULE__, fn _ -> %{} end)

  @impl Adapter
  def start_link(_opts), do: Agent.start_link(&Map.new/0, name: __MODULE__)
end
