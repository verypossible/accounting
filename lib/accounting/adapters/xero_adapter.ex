defmodule Accounting.XeroAdapter do
  @moduledoc """
  The journal adapter for https://developer.xero.com/.
  """

  alias Accounting.{
    Account,
    AccountTransaction,
    Adapter,
    Entry,
    Helpers,
    Journal,
    XeroView,
  }
  import Helpers, only: [sort_transactions: 1]
  import XeroView, only: [render: 1, render: 2]

  @behaviour Adapter

  @typep account_number :: Accounting.account_number
  @typep configs :: %{required(Journal.id) => journal_config}
  @typep credentials :: %OAuther.Credentials{method: :rsa_sha1, token_secret: nil}
  @typep journal :: %{required(binary) => any}
  @typep journal_config :: %{bank_account_id: String.t, credentials: credentials, tracking_category_id: String.t}
  @typep offset :: non_neg_integer
  @typep transactions :: %{optional(account_number) => [AccountTransaction.t]}

  @rate_limit_delay 1_000
  @xero_name_char_limit 150

  @impl Adapter
  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}}
  end

  @impl Adapter
  def start_link(opts) do
    http_client = Keyword.get(opts, :http_client, __MODULE__.DefaultHTTPClient)
    journal_opts = Keyword.get(opts, :journal_opts, %{})

    with {:ok, configs} <- build_configs(http_client, journal_opts),
         {:ok, pid}     <- do_start_link(http_client, configs) do
      memo = Agent.get(pid, & &1.memo)
      Agent.cast memo, fn _ ->
        Enum.reduce(configs, %{}, fn {journal_id, _}, acc ->
          Map.put(acc, journal_id, journal_memo(journal_id))
        end)
      end
      {:ok, pid}
    end
  end

  defp journal_memo(journal_id) do
    case fetch_new(journal_id, 0, %{}, 15_000) do
      {:ok, txns, offset} ->
        %{next_offset: offset, transactions: txns, updated: now()}
      _ ->
        %{next_offset: 0, transactions: %{}, updated: now()}
    end
  end

  @spec build_configs(module, %{required(Journal.id) => keyword}) :: {:ok, configs} | {:error, term}
  defp build_configs(http_client, journal_opts) do
    Enum.reduce_while journal_opts, {:ok, %{}}, fn
      {journal_id, opts}, {:ok, acc} ->
        case build_journal_config(http_client, opts) do
          {:ok, config} -> {:cont, {:ok, Map.put(acc, journal_id, config)}}
          error -> {:halt, error}
        end
    end
  end

  @spec build_journal_config(module, keyword) :: {:ok, journal_config} | {:error, term}
  defp build_journal_config(http_client, opts) do
    consumer_key = Keyword.fetch!(opts, :consumer_key)
    credentials = %OAuther.Credentials{
      consumer_key: consumer_key,
      consumer_secret: Keyword.fetch!(opts, :consumer_secret),
      token: consumer_key,
      method: :rsa_sha1,
    }

    with {:ok, cat_id} <- ensure_tracking_category_exists(http_client, credentials) do
      config = %{
        bank_account_id: Keyword.fetch!(opts, :bank_account_id),
        credentials: credentials,
        tracking_category_id: cat_id,
      }
      {:ok, config}
    end
  end

  @spec do_start_link(module, configs) :: Agent.on_start
  defp do_start_link(http_client, configs) do
    Agent.start_link fn ->
      {:ok, memo} = Agent.start_link(fn -> nil end)
      %{configs: configs, http_client: http_client, memo: memo}
    end, name: __MODULE__
  end

  @spec ensure_tracking_category_exists(module, credentials) :: {:ok, String.t} | {:error, term}
  defp ensure_tracking_category_exists(http_client, credentials) do
    "TrackingCategories/Category"
    |> http_client.get(5_000, credentials)
    |> ensure_tracking_category_exists(http_client, credentials)
  end

  @spec ensure_tracking_category_exists({:ok | :error, term}, module, credentials) :: {:ok, String.t} | {:error, term}
  defp ensure_tracking_category_exists({:ok, %{status_code: 200, body: "{" <> _ = json}}, _http_client, _credentials) do
    tracking_category_id =
      json
      |> Poison.decode!()
      |> Map.fetch!("TrackingCategories")
      |> hd()
      |> Map.fetch!("TrackingCategoryID")

    {:ok, tracking_category_id}
  end
  defp ensure_tracking_category_exists({:ok, %{status_code: 404}}, http_client, credentials) do
    "start_link.xml"
    |> render()
    |> http_client.put("TrackingCategories", 5_000, credentials)
    |> ensure_tracking_category_exists(http_client, credentials)
  end
  defp ensure_tracking_category_exists({_, reasons}, _http_client, _credentials) do
    {:error, reasons}
  end

  @impl Adapter
  def register_categories(journal_id, categories, timeout) when is_list(categories) do
    creds = creds(journal_id)
    id =
      Agent.get(__MODULE__, fn state ->
        get_in(state, [:configs, journal_id, :tracking_category_id])
      end, timeout)

    "register_categories.xml"
    |> render(categories: categories)
    |> http_client().put("TrackingCategories/#{id}/Options", timeout, creds)
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
  def setup_accounts(journal_id, accounts, timeout) do
    accounts = for a <- accounts do
      length = @xero_name_char_limit - String.length(a.number) + 3
      name = "#{truncate(a.description, length)} - #{a.number}"

      [number: a.number, name: name]
    end

    "setup_accounts.xml"
    |> render(accounts: accounts)
    |> http_client().post("Setup", timeout, creds(journal_id))
    |> handle_http_response()
  end

  @impl Adapter
  def setup_account_conversions(journal_id, month, year, accounts, timeout) do
    accounts = for a <- accounts do
      balance = to_string(a.conversion_balance / 100)
      [number: a.number, conversion_balance: balance]
    end

    "setup_account_conversions.xml"
    |> render(accounts: accounts, month: month, year: year)
    |> http_client().post("Setup", timeout, creds(journal_id))
    |> handle_http_response()
  end

  @spec handle_http_response({:ok, HTTPoison.Response.t} | {:error, Elixir.HTTPoison.Error.t}) :: :ok | {:error, :duplicate | HTTPoison.Error.t}
  defp handle_http_response({:ok, %{status_code: 200}}), do: :ok
  defp handle_http_response({:ok, %{status_code: 400, body: "{" <> _ = json} = reasons}) do
    duplication_error = %{"Message" => "Please enter a unique Code."}

    if duplication_error in validation_errors(json) do
      {:error, :duplicate}
    else
      {:error, reasons}
    end
  end
  defp handle_http_response({_, reasons}), do: {:error, reasons}


  @impl Adapter
  def register_account(journal_id, number, description, timeout) when is_binary(number) do
    length = @xero_name_char_limit - String.length(number) + 3
    name = "#{truncate(description, length)} - #{number}"

    "register_account.xml"
    |> render(number: number, name: name)
    |> http_client().put("Accounts", timeout, creds(journal_id))
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
  def record_entries(journal_id, entries, timeout) do
    case Enum.split_with(entries, & &1.total === 0) do
      {_, []} -> record_invoices(journal_id, entries, timeout)
      {[], _} -> post_bank_transactions(journal_id, entries, timeout)
      _ -> {:error, :mixed_entries}
    end
  end

  @spec post_bank_transactions(Journal.id, [Entry.t], timeout) :: :ok | {:error, term}
  defp post_bank_transactions(_journal_id, [], _timeout), do: :ok
  defp post_bank_transactions(journal_id, entries, timeout) do
    assigns = [bank_account_id: bank_account_id(journal_id), entries: entries]
    params = [summarizeErrors: false]

    "bank_transactions.xml"
    |> render(assigns)
    |> http_client().put("BankTransactions", timeout, creds(journal_id), params)
    |> did_post_bank_transactions(entries)
  end

  @spec did_post_bank_transactions({:ok, HTTPoison.Response.t} | {:error, Elixir.HTTPoison.Error.t}, [Entry.t, ...]) :: :ok | {:error, HTTPoison.Error.t | HTTPoison.Response.t}
  defp did_post_bank_transactions({:ok, %{body: json, status_code: 200}}, entries) do
    bank_transactions =
      json
      |> Poison.decode!()
      |> Map.fetch!("BankTransactions")

    case extract_errors(bank_transactions, entries, []) do
      [] -> :ok
      errors -> {:error, errors}
    end
  end
  defp did_post_bank_transactions({_, reasons}, _entries), do: {:error, reasons}

  @impl Adapter
  @spec record_invoices(Journal.id, [Entry.t], timeout) :: :ok | {:error, term}
  def record_invoices(_journal_id, [], _timeout), do: :ok
  def record_invoices(journal_id, entries, timeout) do
    params = [summarizeErrors: false]

    "invoices.xml"
    |> render(entries: entries)
    |> http_client().put("Invoices", timeout, creds(journal_id), params)
    |> did_record_invoices(entries)
  end

  @spec did_record_invoices({:ok, HTTPoison.Response.t} | {:error, Elixir.HTTPoison.Error.t}, [Entry.t, ...]) :: :ok | {:error, HTTPoison.Error.t | HTTPoison.Response.t}
  defp did_record_invoices({:ok, %{body: json, status_code: 200}}, entries) do
    invoices =
      json
      |> Poison.decode!()
      |> Map.fetch!("Invoices")

    case extract_errors(invoices, entries, []) do
      [] -> :ok
      errors -> {:error, errors}
    end
  end
  defp did_record_invoices({_, reasons}, _entries), do: {:error, reasons}

  @spec extract_errors([map], [Entry.t], [Entry.Error.t]) :: [Entry.Error.t]
  defp extract_errors([], _, acc), do: Enum.reverse(acc)
  defp extract_errors([map|maps], [entry|entries], acc) do
    case Map.get(map, "ValidationErrors", []) do
      [] ->
        extract_errors(maps, entries, acc)
      validation_errors ->
        errors = for e <- validation_errors, do: e["Message"]
        new_acc = [%Entry.Error{entry: entry, errors: errors}|acc]
        extract_errors(maps, entries, new_acc)
    end
  end

  @spec bank_account_id(Journal.id) :: String.t
  defp bank_account_id(journal_id) do
    Agent.get(__MODULE__, & &1.configs[journal_id].bank_account_id)
  end

  @impl Adapter
  def list_accounts(journal_id, timeout) do
    creds = creds(journal_id)
    with {:ok, resp} <- http_client().get("Accounts", timeout, creds) do
      resp.body
      |> Poison.decode!
      |> Map.fetch!("Accounts")
      |> Stream.map(&(Map.get(&1, "Code")))
      |> Enum.filter(&(&1))
      |> (&({:ok, &1})).()
    end
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
    creds = creds(journal_id)

    case http_client().get("Journals", timeout, creds, offset: offset) do
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

  @spec creds(Journal.id) :: credentials
  defp creds(journal_id) do
    Agent.get(__MODULE__, &Map.fetch!(&1.configs, journal_id)).credentials
  end

  @spec http_client() :: module
  defp http_client, do: Agent.get(__MODULE__, &Map.fetch!(&1, :http_client))
end
