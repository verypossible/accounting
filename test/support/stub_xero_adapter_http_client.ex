defmodule StubXeroAdapterHTTPClient do
  @moduledoc """
  A stub for the XeroAdapter HTTPClient.
  """

  alias Accounting.XeroAdapter

  @behaviour XeroAdapter.HTTPClient

  @impl XeroAdapter.HTTPClient
  def get(endpoint, timeout, credentials, params \\ [])
  def get("TrackingCategories/Category", _, _, _) do
    value = %{
      "TrackingCategories" => [
        %{"TrackingCategoryID" => "FakeCategoryId"},
      ],
    }
    body = Poison.encode!(value)
    {:ok, %HTTPoison.Response{status_code: 200, headers: [], body: body}}
  end
  def get("Journals", _, _, _) do
    body = Poison.encode!(%{"Journals" => []})
    {:ok, %HTTPoison.Response{status_code: 200, headers: [], body: body}}
  end
  def get(endpoint, timeout, credentials, params) do
    send self(), {:http_get, endpoint, timeout, credentials, params}
    {:ok, %HTTPoison.Response{status_code: 200, headers: []}}
  end

  @impl XeroAdapter.HTTPClient
  def put(xml, endpoint, timeout, credentials, params \\ []) do
    send self(), {:http_put, xml, endpoint, timeout, credentials, params}
    case endpoint do
      "BankTransactions" -> put_bank_transactions(timeout)
      "Invoices" -> put_invoices(timeout)
      _ -> {:ok, %HTTPoison.Response{status_code: 200}}
    end
  end

  @spec put_bank_transactions(timeout) :: {:ok, HTTPoison.Response.t} | {:error, HTTPoison.Error.t}
  defp put_bank_transactions(timeout) do
    case timeout do
      1 ->
        {:error, %HTTPoison.Error{reason: HTTPoison.SuperError}}
      2 ->
        {:ok, %HTTPoison.Response{status_code: 400}}
      3 ->
        bank_transactions = [
          %{ValidationErrors: []},
          %{ValidationErrors: [%{Message: "Something terrible has occurred!"}]},
          %{},
          %{
            ValidationErrors: [
              %{Message: "The sky is falling!"},
              %{Message: "Fix dis now!"},
              %{Message: "I give up."},
            ],
          },
        ]
        body = Poison.encode!(%{BankTransactions: bank_transactions})
        response = %HTTPoison.Response{body: body, status_code: 200}
        {:ok, response}
      _ ->
        body = Poison.encode!(%{BankTransactions: []})
        response = %HTTPoison.Response{body: body, status_code: 200}
        {:ok, response}
    end
  end

  @spec put_invoices(timeout) :: {:ok, HTTPoison.Response.t}
  defp put_invoices(timeout) do
    case timeout do
      3 ->
        invoices = [
          %{ValidationErrors: []},
          %{ValidationErrors: [%{Message: "Something terrible has occurred!"}]},
          %{},
          %{
            ValidationErrors: [
              %{Message: "The sky is falling!"},
              %{Message: "Fix dis now!"},
              %{Message: "I give up."},
            ],
          },
        ]
        body = Poison.encode!(%{Invoices: invoices})
        response = %HTTPoison.Response{body: body, status_code: 200}
        {:ok, response}
      _ ->
        body = Poison.encode!(%{Invoices: []})
        response = %HTTPoison.Response{body: body, status_code: 200}
        {:ok, response}
    end
  end
end
