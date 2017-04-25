defmodule Accounting.XeroAdapter do
  alias Accounting.AccountTransaction
  import Accounting.XeroView, only: [render: 1, render: 2]

  @moduledoc false

  @behaviour Accounting.Adapter

  @typep offset :: non_neg_integer

  @rate_limit_delay 1_000
  @xero_name_char_limit 150

  ## Callbacks

  def start_link do
    with {:ok, category_id} <- ensure_tracking_category_exists(),
         {:ok, pid}         <- start_link(category_id) do
      memo = Agent.get(pid, &Map.fetch!(&1, :memo))
      Agent.cast memo, fn _ ->
        case fetch_new(0, %{}, 15_000) do
          {:ok, txns, offset} -> %{next_offset: offset, transactions: txns}
          _ -> %{next_offset: 0, transactions: %{}}
        end
      end
      {:ok, pid}
    end
  end

  defp start_link(tracking_category_id) do
    Agent.start_link fn ->
      {:ok, memo} = Agent.start_link(fn -> nil end)
      %{tracking_category_id: tracking_category_id, memo: memo}
    end, name: __MODULE__
  end

  defp ensure_tracking_category_exists() do
    "TrackingCategories/Category"
    |> get(5_000)
    |> ensure_tracking_category_exists()
  end

  defp ensure_tracking_category_exists({:ok, %{status_code: 200, body: "{" <> _ = json}}) do
    tracking_category_id =
      json
      |> Poison.decode!()
      |> Map.fetch!("TrackingCategories")
      |> hd()
      |> Map.fetch!("TrackingCategoryID")

    {:ok, tracking_category_id}
  end
  defp ensure_tracking_category_exists({:ok, %{status_code: 404}}) do
    "start_link.xml"
    |> render()
    |> put("TrackingCategories", 5_000)
    |> ensure_tracking_category_exists()
  end
  defp ensure_tracking_category_exists({_, reasons}), do: {:error, reasons}

  def register_categories(categories, timeout) when is_list(categories) do
    id = Agent.get(__MODULE__, &Map.fetch!(&1, :tracking_category_id), timeout)

    "register_categories.xml"
    |> render(categories: categories)
    |> put("TrackingCategories/#{id}/Options", timeout)
    |> did_register_categories()
  end

  defp did_register_categories({:ok, %{status_code: 200}}), do: :ok
  defp did_register_categories({:ok, %{status_code: 400, body: "{" <> _ = json} = reasons}) do
    duplication_error = %{
      "Message" =>
        "For each specified tracking option the name must be unique.",
    }
    if duplication_error in validation_errors(json) do
      {:error, :duplicate}
    else
      {:error, reasons}
    end
  end
  defp did_register_categories({_, reasons}), do: {:error, reasons}

  def create_account(number, description, timeout) when is_binary(number) do
    length = @xero_name_char_limit - String.length(number) + 3
    name = "#{truncate(description, length)} - #{number}"

    "create_account.xml"
    |> render(number: number, name: name)
    |> put("Accounts", timeout)
    |> did_create_account()
  end

  defp truncate(string, length) when byte_size(string) > length do
    String.slice(string, 0..length - 4) <> "..."
  end
  defp truncate(string, _length), do: string

  defp did_create_account({:ok, %{status_code: 200}}), do: :ok
  defp did_create_account({:ok, %{status_code: 400, body: "{" <> _ = json} = reasons}) do
    duplication_error = %{"Message" => "Please enter a unique Code."}

    if duplication_error in validation_errors(json) do
      {:error, :duplicate}
    else
      {:error, reasons}
    end
  end
  defp did_create_account({_, reasons}), do: {:error, reasons}

  defp validation_errors(json) when is_binary(json) do
    json
    |> Poison.decode!()
    |> validation_errors()
  end
  defp validation_errors(%{"Elements" => [%{"ValidationErrors" => e}|_]}), do: e
  defp validation_errors(%{}), do: []

  def receive_money(<<_::binary>> = from, %Date{} = date, [_|_] = line_items, timeout) do
    line_items
    |> Enum.reduce(0, & &1.amount + &2)
    |> do_receive_money(from, date, line_items, timeout)
  end

  defp do_receive_money(0, from, date, line_items, timeout) do
    "transfer.xml"
    |> render(from: from, date: date, line_items: line_items)
    |> put("Invoices", timeout)
    |> did_transfer()
  end
  defp do_receive_money(_, from, date, line_items, timeout) do
    "receive_money.xml"
    |> render(from: from, date: date, line_items: line_items)
    |> put("BankTransactions", timeout)
    |> did_receive_money()
  end

  def spend_money(<<_::binary>> = to, %Date{} = date, [_|_] = line_items, timeout) do
    line_items
    |> Enum.reduce(0, & &1.amount + &2)
    |> do_spend_money(to, date, line_items, timeout)
  end

  defp do_spend_money(0, to, date, line_items, timeout) do
    "transfer.xml"
    |> render(to: to, date: date, line_items: line_items)
    |> put("Invoices", timeout)
    |> did_transfer()
  end
  defp do_spend_money(_, to, date, line_items, timeout) do
    "spend_money.xml"
    |> render(to: to, date: date, line_items: line_items)
    |> put("BankTransactions", timeout)
    |> did_spend_money()
  end

  defp did_transfer({:ok, %{status_code: 200}}), do: :ok
  defp did_transfer({_, reasons}), do: {:error, reasons}

  defp did_receive_money({:ok, %{status_code: 200}}), do: :ok
  defp did_receive_money({_, reasons}), do: {:error, reasons}

  defp did_spend_money({:ok, %{status_code: 200}}), do: :ok
  defp did_spend_money({_, reasons}), do: {:error, reasons}

  defp put(xml, endpoint, timeout) do
    url = "https://api.xero.com/api.xro/2.0/#{endpoint}"
    {oauth_header, _} =
      "put"
      |> OAuther.sign(url, [], credentials())
      |> OAuther.header()

    HTTPoison.put url, xml, [oauth_header, {"Accept", "application/json"}],
      recv_timeout: timeout
  end

  def fetch_account_transactions(number, timeout) when is_binary(number) do
    memo = Agent.get(__MODULE__, &Map.fetch!(&1, :memo), timeout)
    Agent.get_and_update memo, fn state ->
      case fetch_new(state.next_offset, state.transactions, timeout) do
        {:ok, txns, offset} ->
          value = {:ok, Enum.reverse(txns[number] || [])}
          new_state = %{transactions: txns, next_offset: offset}
          {value, new_state}
        error ->
          {error, state}
      end
    end, timeout
  end

  @spec fetch_new(offset, map, timeout) :: {:ok, map, offset} | {:error, term}
  defp fetch_new(offset, acc, timeout) do
    case get("Journals", timeout, offset: offset) do
      {:ok, %{body: "{" <> _ = json}} ->
        journals =
          json
          |> Poison.decode!()
          |> Map.fetch!("Journals")

        transactions = Enum.reduce(journals, acc, &import_journal/2)

        if length(journals) === 100 do
          Process.sleep(@rate_limit_delay)
          fetch_new(offset + 100, transactions, timeout)
        else
          {:ok, transactions, next_offset(journals) || offset}
        end

      {:ok, %{headers: headers, status_code: 503}} ->
        case :proplists.get_value("X-Rate-Limit-Problem", headers) do
          "Minute" -> {:error, {:rate_limit_exceeded, :minute}}
          "Daily" -> {:error, {:rate_limit_exceeded, :day}}
          :undefined -> {:error, :rate_limit_exceeded}
        end

      {_, reasons} ->
        {:error, reasons}
    end
  end

  defp import_journal(journal, transactions) do
    Enum.reduce journal["JournalLines"], transactions, fn
      %{"AccountCode" => account_number} = line, acc ->
        txn = %AccountTransaction{
          amount: -round(line["GrossAmount"] * 100),
          description: line["Description"],
          date: date(journal["JournalDate"]),
        }
        Map.update(acc, account_number, [txn], fn list -> [txn|list] end)
      _, acc ->
        acc
    end
  end

  defp date(xero_date) do
    [_, milliseconds] = Regex.run(~r/\/Date\((-?\d+)\+0000\)\//, xero_date)

    milliseconds
    |> String.to_integer()
    |> DateTime.from_unix!(:milliseconds)
    |> DateTime.to_date()
  end

  defp next_offset([]), do: nil
  defp next_offset(journals) do
    journals
    |> List.last()
    |> Map.fetch!("JournalNumber")
  end

  defp get(endpoint, timeout, params \\ []) do
    query = URI.encode_query(params)
    url = "https://api.xero.com/api.xro/2.0/#{endpoint}?#{query}"
    {oauth_header, _} =
      "get"
      |> OAuther.sign(url, [], credentials())
      |> OAuther.header()

    HTTPoison.get url, [oauth_header, {"Accept", "application/json"}],
      recv_timeout: timeout
  end

  defp credentials do
    consumer_secret = Application.get_env(:accounting, :consumer_secret)
    consumer_key    = Application.get_env(:accounting, :consumer_key)
    %OAuther.Credentials{
      consumer_key: consumer_key,
      consumer_secret: consumer_secret,
      token: consumer_key,
      method: :rsa_sha1,
    }
  end
end
