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
  @typep configs :: %{required(Journal.id) => journal_config}
  @typep credentials :: %OAuther.Credentials{method: :rsa_sha1, token_secret: nil}
  @typep journal :: %{required(binary) => any}
  @typep journal_config :: %{bank_account_id: String.t, credentials: %OAuther.Credentials{}, tracking_category_id: String.t}
  @typep offset :: non_neg_integer
  @typep transactions :: %{optional(account_number) => [AccountTransaction.t]}

  @rate_limit_delay 1_000
  @xero_name_char_limit 150

  @impl Adapter
  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}}
  end

  @impl Adapter
  def start_link(journal_opts) do
    with {:ok, configs} <- build_configs(journal_opts),
         {:ok, pid}     <- do_start_link(configs) do
      memo = Agent.get(pid, & &1.memo)
      Agent.cast memo, fn _ ->
        Enum.reduce(configs, %{}, fn {journal_id, _}, acc ->
          journal_memo =
            case fetch_new(journal_id, 0, %{}, 15_000) do
              {:ok, txns, offset} ->
                %{next_offset: offset, transactions: txns, updated: now()}
              _ ->
                %{next_offset: 0, transactions: %{}, updated: now()}
            end

          Map.put(acc, journal_id, journal_memo)
        end)
      end
      {:ok, pid}
    end
  end

  @spec build_configs(%{required(Journal.id) => keyword}) :: {:ok, configs} | {:error, term}
  defp build_configs(journal_opts) do
    Enum.reduce_while journal_opts, {:ok, %{}}, fn
      {journal_id, opts}, {:ok, acc} ->
        case build_journal_config(opts) do
          {:ok, config} -> {:cont, {:ok, Map.put(acc, journal_id, config)}}
          error -> {:halt, error}
        end
    end
  end

  @spec build_journal_config(keyword) :: {:ok, journal_config} | {:error, term}
  defp build_journal_config(opts) do
    consumer_key = Keyword.fetch!(opts, :consumer_key)
    credentials = %OAuther.Credentials{
      consumer_key: consumer_key,
      consumer_secret: Keyword.fetch!(opts, :consumer_secret),
      token: consumer_key,
      method: :rsa_sha1,
    }

    with {:ok, cat_id} <- ensure_tracking_category_exists(credentials) do
      config = %{
        bank_account_id: Keyword.fetch!(opts, :bank_account_id),
        credentials: credentials,
        tracking_category_id: cat_id,
      }
      {:ok, config}
    end
  end

  @spec do_start_link(configs) :: Agent.on_start
  defp do_start_link(configs) do
    Agent.start_link fn ->
      {:ok, memo} = Agent.start_link(fn -> nil end)
      %{configs: configs, memo: memo}
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
  def register_categories(journal_id, categories, timeout) when is_list(categories) do
    id = Agent.get(__MODULE__, &get_in(&1, [:configs, journal_id, :tracking_category_id]), timeout)
    "register_categories.xml"
    |> render(categories: categories)
    |> put("TrackingCategories/#{id}/Options", timeout, credentials(journal_id))
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
  def register_account(journal_id, number, description, timeout) when is_binary(number) do
    length = @xero_name_char_limit - String.length(number) + 3
    name = "#{truncate(description, length)} - #{number}"

    "register_account.xml"
    |> render(number: number, name: name)
    |> put("Accounts", timeout, credentials(journal_id))
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
  def record_entry(journal_id, <<_::binary>> = party, %Date{} = date, [_|_] = line_items, timeout) do
    total = line_items
    |> Enum.reduce(0, & &1.amount + &2)

    record_entry(journal_id, total, party, date, line_items, timeout)
  end

  @spec record_entry(Journal.id, integer, String.t, Date.t, [LineItem.t], timeout) :: :ok | {:error, term}
  defp record_entry(journal_id, 0, party, date, line_items, timeout) do
    "record_transfer.xml"
    |> render(date: date, line_items: line_items, party: party)
    |> put("Invoices", timeout, credentials(journal_id))
    |> did_record_entry()
  end
  defp record_entry(journal_id, total, party, date, line_items, timeout) when total < 0 do
    assigns = [
      bank_account_id: bank_account_id(journal_id),
      date: date,
      line_items: for(l <- line_items, do: %{l | amount: -l.amount}),
      party: party,
    ]

    "record_debit.xml"
    |> render(assigns)
    |> put("BankTransactions", timeout, credentials(journal_id))
    |> did_record_entry()
  end
  defp record_entry(journal_id, _, party, date, line_items, timeout) do
    assigns = [
      bank_account_id: bank_account_id(journal_id),
      date: date,
      line_items: line_items,
      party: party,
    ]

    "record_credit.xml"
    |> render(assigns)
    |> put("BankTransactions", timeout, credentials(journal_id))
    |> did_record_entry()
  end

  @spec did_record_entry({:ok, HTTPoison.Response.t} | {:error, Elixir.HTTPoison.Error.t}) :: :ok | {:error, :duplicate | HTTPoison.Error.t}
  defp did_record_entry({:ok, %{status_code: 200}}), do: :ok
  defp did_record_entry({_, reasons}), do: {:error, reasons}

  @spec bank_account_id(Journal.id) :: String.t
  defp bank_account_id(journal_id) do
    Agent.get(__MODULE__, & &1.configs[journal_id].bank_account_id)
  end

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
  def fetch_accounts(journal_id, numbers, timeout) when is_list(numbers) do
    memo = Agent.get(__MODULE__, & &1.memo, timeout)
    Agent.get_and_update memo, fn %{^journal_id => journal_memo} = state ->
      %{
        next_offset: offset,
        transactions: txns,
        updated: updated,
      } = journal_memo
      if updated !== now() do
        case fetch_new(journal_id, offset, txns, timeout) do
          {:ok, new_txns, new_offset} ->
            value = {:ok, get_accounts(new_txns, numbers)}
            new_journal_memo = %{
              next_offset: new_offset,
              transactions: new_txns,
              updated: now(),
            }
            {value, Map.put(state, journal_id, new_journal_memo)}
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

  @spec fetch_new(Journal.id, offset, map, timeout) :: {:ok, map, offset} | {:error, term}
  defp fetch_new(journal_id, offset, acc, timeout) do
    case get("Journals", timeout, credentials(journal_id), offset: offset) do
      {:ok, %{body: "{" <> _ = json}} ->
        journals =
          json
          |> Poison.decode!()
          |> Map.fetch!("Journals")

        transactions = Enum.reduce(journals, acc, &import_journal/2)

        if length(journals) === 100 do
          Process.sleep(@rate_limit_delay)
          fetch_new(journal_id, offset + 100, transactions, timeout)
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

  @spec credentials(Journal.id) :: %OAuther.Credentials{}
  defp credentials(journal_id) do
    Agent.get(__MODULE__, &Map.fetch!(&1.configs, journal_id)).credentials
  end
end
