defmodule Accounting.XeroAdapter do
  alias Accounting.{
    Account,
    AccountTransaction,
    Adapter,
    Helpers,
    Journal,
    LineItem,
    XeroView,
  }
  import Helpers, only: [sort_transactions: 1]
  import XeroView, only: [render: 1, render: 2]

  @behaviour Adapter

  @typep account_number :: Accounting.account_number
  @typep credentials :: %OAuther.Credentials{method: :rsa_sha1, token_secret: nil}
  @typep journal :: %{required(binary) => any}
  @typep offset :: non_neg_integer
  @typep transactions :: %{optional(account_number) => [AccountTransaction.t]}

  @rate_limit_delay 1_000
  @xero_name_char_limit 150

  @impl Adapter
  def child_spec(opts), do: Supervisor.Spec.worker(__MODULE__, [opts])

  @impl Adapter
  def start_link(opts) do
    consumer_key = Keyword.fetch!(opts, :consumer_key)
    credentials = %OAuther.Credentials{
      consumer_key: consumer_key,
      consumer_secret: Keyword.fetch!(opts, :consumer_secret),
      token: consumer_key,
      method: :rsa_sha1,
    }
    config = %{
      bank_account_id: Keyword.fetch!(opts, :bank_account_id),
      credentials: credentials,
    }
    with {:ok, category_id} <- ensure_tracking_category_exists(credentials),
         {:ok, pid}         <- do_start_link(category_id, config) do
      memo = Agent.get(pid, & &1.memo)
      Agent.cast memo, fn _ ->
        case fetch_new(0, %{}, 15_000) do
          {:ok, txns, offset} ->
            %{next_offset: offset, transactions: txns, updated: now()}
          _ ->
            %{next_offset: 0, transactions: %{}, updated: now()}
        end
      end
      {:ok, pid}
    end
  end

  @spec do_start_link(String.t, config :: %{bank_account_id: String.t, credentials: %OAuther.Credentials{}}) :: Agent.on_start
  defp do_start_link(tracking_category_id, config) do
    Agent.start_link fn ->
      {:ok, memo} = Agent.start_link(fn -> nil end)
      %{
        bank_account_id: config.bank_account_id,
        credentials: config.credentials,
        memo: memo,
        tracking_category_id: tracking_category_id,
      }
    end, name: __MODULE__
  end

  @spec ensure_tracking_category_exists(credentials) :: {:ok, String.t} | {:error, term}
  defp ensure_tracking_category_exists(credentials) do
    "TrackingCategories/Category"
    |> get(5_000, credentials)
    |> ensure_tracking_category_exists(credentials)
  end

  @spec ensure_tracking_category_exists({:ok | :error, term}, %OAuther.Credentials{}) :: {:ok, String.t} | {:error, term}
  defp ensure_tracking_category_exists({:ok, %{status_code: 200, body: "{" <> _ = json}}, _credentials) do
    tracking_category_id =
      json
      |> Poison.decode!()
      |> Map.fetch!("TrackingCategories")
      |> hd()
      |> Map.fetch!("TrackingCategoryID")

    {:ok, tracking_category_id}
  end
  defp ensure_tracking_category_exists({:ok, %{status_code: 404}}, credentials) do
    "start_link.xml"
    |> render()
    |> put("TrackingCategories", 5_000, credentials)
    |> ensure_tracking_category_exists(credentials)
  end
  defp ensure_tracking_category_exists({_, reasons}, _credentials) do
    {:error, reasons}
  end

  @impl Adapter
  def register_categories(categories, timeout) when is_list(categories) do
    id = Agent.get(__MODULE__, & &1.tracking_category_id, timeout)

    "register_categories.xml"
    |> render(categories: categories)
    |> put("TrackingCategories/#{id}/Options", timeout, credentials())
    |> did_register_categories()
  end

  @spec did_register_categories({:ok, HTTPoison.Response.t} | {:error, HTTPoison.Error.t}) :: :ok | {:error, :duplicate | HTTPoison.Error.t}
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

  @impl Adapter
  def register_account(number, description, timeout) when is_binary(number) do
    length = @xero_name_char_limit - String.length(number) + 3
    name = "#{truncate(description, length)} - #{number}"

    "register_account.xml"
    |> render(number: number, name: name)
    |> put("Accounts", timeout, credentials())
    |> did_register_account()
  end

  @spec truncate(String.t, integer) :: String.t
  defp truncate(string, length) when byte_size(string) > length do
    String.slice(string, 0..length - 4) <> "..."
  end
  defp truncate(string, _length), do: string

  @spec did_register_account({:ok, HTTPoison.Response.t} | {:error, Elixir.HTTPoison.Error.t}) :: :ok | {:error, :duplicate | HTTPoison.Error.t}
  defp did_register_account({:ok, %{status_code: 200}}), do: :ok
  defp did_register_account({:ok, %{status_code: 400, body: "{" <> _ = json} = reasons}) do
    duplication_error = %{"Message" => "Please enter a unique Code."}

    if duplication_error in validation_errors(json) do
      {:error, :duplicate}
    else
      {:error, reasons}
    end
  end
  defp did_register_account({_, reasons}), do: {:error, reasons}

  @spec validation_errors(String.t | map) :: [String.t]
  defp validation_errors(json) when is_binary(json) do
    json
    |> Poison.decode!()
    |> validation_errors()
  end
  defp validation_errors(%{"Elements" => [%{"ValidationErrors" => e}|_]}), do: e
  defp validation_errors(%{}), do: []

  @impl Adapter
  def record_entry(<<_::binary>> = party, %Date{} = date, [_|_] = line_items, timeout) do
    line_items
    |> Enum.reduce(0, & &1.amount + &2)
    |> record_entry(party, date, line_items, timeout)
  end

  @spec record_entry(integer, String.t, Date.t, [LineItem.t], timeout) :: :ok | {:error, term}
  defp record_entry(0, party, date, line_items, timeout) do
    "record_transfer.xml"
    |> render(date: date, line_items: line_items, party: party)
    |> put("Invoices", timeout, credentials())
    |> did_record_entry()
  end
  defp record_entry(total, party, date, line_items, timeout) when total < 0 do
    assigns = [
      bank_account_id: bank_account_id(),
      date: date,
      line_items: for(l <- line_items, do: %{l | amount: -l.amount}),
      party: party,
    ]

    "record_debit.xml"
    |> render(assigns)
    |> put("BankTransactions", timeout, credentials())
    |> did_record_entry()
  end
  defp record_entry(_, party, date, line_items, timeout) do
    assigns = [
      bank_account_id: bank_account_id(),
      date: date,
      line_items: line_items,
      party: party,
    ]

    "record_credit.xml"
    |> render(assigns)
    |> put("BankTransactions", timeout, credentials())
    |> did_record_entry()
  end

  @spec did_record_entry({:ok, HTTPoison.Response.t} | {:error, Elixir.HTTPoison.Error.t}) :: :ok | {:error, :duplicate | HTTPoison.Error.t}
  defp did_record_entry({:ok, %{status_code: 200}}), do: :ok
  defp did_record_entry({_, reasons}), do: {:error, reasons}

  @spec bank_account_id() :: String.t
  defp bank_account_id, do: Agent.get(__MODULE__, & &1.bank_account_id)

  @spec put(String.t, String.t, timeout, %OAuther.Credentials{}) :: {:ok, HTTPoison.Response.t | HTTPoison.AsyncResponse.t} | {:error, HTTPoison.Error.t}
  defp put(xml, endpoint, timeout, credentials) do
    url = "https://api.xero.com/api.xro/2.0/#{endpoint}"
    {oauth_header, _} =
      "put"
      |> OAuther.sign(url, [], credentials)
      |> OAuther.header()

    HTTPoison.put url, xml, [oauth_header, {"Accept", "application/json"}],
      recv_timeout: timeout
  end

  @impl Adapter
  def fetch_accounts(numbers, timeout) when is_list(numbers) do
    memo = Agent.get(__MODULE__, & &1.memo, timeout)
    Agent.get_and_update memo, fn
      %{next_offset: offset, transactions: txns, updated: updated} = state ->
        if updated !== now() do
          case fetch_new(offset, txns, timeout) do
            {:ok, new_txns, new_offset} ->
              value = {:ok, get_accounts(new_txns, numbers)}
              new_state = %{
                transactions: new_txns,
                next_offset: new_offset,
                updated: now(),
              }
              {value, new_state}
            error ->
              {error, state}
          end
        else
          value = {:ok, get_accounts(txns, numbers)}
          {value, state}
        end
    end, timeout
  end

  @spec get_accounts(transactions, [account_number]) :: Journal.accounts
  defp get_accounts(transactions, numbers) do
    for number <- numbers, into: %{} do
      account = %Account{
        number: number,
        transactions: sort_transactions(transactions[number] || []),
      }
      {number, account}
    end
  end

  @spec fetch_new(offset, map, timeout) :: {:ok, map, offset} | {:error, term}
  defp fetch_new(offset, acc, timeout) do
    case get("Journals", timeout, credentials(), offset: offset) do
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

  @spec now() :: integer
  defp now, do: :erlang.system_time(:seconds)

  @spec import_journal(journal, transactions) :: transactions
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

  @spec date(String.t) :: Date.t
  defp date(xero_date) do
    [_, milliseconds] = Regex.run(~r/\/Date\((-?\d+)\+0000\)\//, xero_date)

    milliseconds
    |> String.to_integer()
    |> DateTime.from_unix!(:milliseconds)
    |> DateTime.to_date()
  end

  @spec next_offset([journal]) :: offset | nil
  defp next_offset([]), do: nil
  defp next_offset(journals) do
    journals
    |> List.last()
    |> Map.fetch!("JournalNumber")
  end

  @spec get(String.t, timeout, credentials, keyword) :: {:ok, HTTPoison.Response.t} | {:error, HTTPoison.Error.t}
  defp get(endpoint, timeout, credentials, params \\ []) do
    query = URI.encode_query(params)
    url = "https://api.xero.com/api.xro/2.0/#{endpoint}?#{query}"
    {oauth_header, _} =
      "get"
      |> OAuther.sign(url, [], credentials)
      |> OAuther.header()

    HTTPoison.get url, [oauth_header, {"Accept", "application/json"}],
      recv_timeout: timeout
  end

  @spec credentials() :: %OAuther.Credentials{}
  defp credentials, do: Agent.get(__MODULE__, & &1.credentials)
end
