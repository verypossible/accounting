defmodule Accounting.TestAdapter do
  @behaviour Accounting.Adapter

  alias Accounting.AccountTransaction

  def reset, do: Agent.update(__MODULE__, fn _ -> %{} end)

  ## Callbacks

  def start_link, do: Agent.start_link(&Map.new/0, name: __MODULE__)

  def register_categories(categories) do
    Enum.each categories, fn category ->
      send self(), {:registered_category, category}
    end
  end

  def create_account(number) do
    send self(), {:created_account, number}

    if exists?(number) do
      {:error, :duplicate}
    else
      Agent.update(__MODULE__, &Map.put(&1, number, []))
    end
  end

  defp exists?(account_number) do
    Agent.get(__MODULE__, &Map.has_key?(&1, account_number))
  end

  def receive_money(<<_::binary>> = from, %Date{} = date, [_|_] = line_items) do
    Enum.each line_items, fn item ->
      send self(), {:received_money, from, date, item}
    end

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

  defp all_exist?(account_numbers) do
    Agent.get __MODULE__, fn state ->
      Enum.all?(account_numbers, &Map.has_key?(state, &1))
    end
  end

  def fetch_account_transactions(number) do
    {:ok, get_account_transactions(number)}
  end

  defp get_account_transactions(number) do
    if account_data = Agent.get(__MODULE__, &Map.get(&1, number)) do
      Enum.reverse(account_data)
    else
      []
    end
  end
end
