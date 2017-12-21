defmodule Accounting.XeroAdapter.DefaultHTTPClient do
  @moduledoc """
  A default HTTP client for the XeroAdapter.
  """

  alias Accounting.XeroAdapter

  @behaviour XeroAdapter.HTTPClient

  @impl XeroAdapter.HTTPClient
  def get(endpoint, timeout, credentials, params \\ []) do
    query = URI.encode_query(params)
    url = "https://api.xero.com/api.xro/2.0/#{endpoint}?#{query}"
    {oauth_header, _} =
      "get"
      |> OAuther.sign(url, [], credentials)
      |> OAuther.header()

    HTTPoison.get url, [oauth_header, {"Accept", "application/json"}],
      recv_timeout: timeout
  end

  @impl XeroAdapter.HTTPClient
  def post(xml, endpoint, timeout, credentials, params \\ []) do
    query = URI.encode_query(params)
    url = "https://api.xero.com/api.xro/2.0/#{endpoint}?#{query}"
    {oauth_header, _} =
      "post"
      |> OAuther.sign(url, [], credentials)
      |> OAuther.header()

    HTTPoison.put url, xml, [oauth_header, {"Accept", "application/json"}],
      recv_timeout: timeout
  end

  @impl XeroAdapter.HTTPClient
  def put(xml, endpoint, timeout, credentials, params \\ []) do
    query = URI.encode_query(params)
    url = "https://api.xero.com/api.xro/2.0/#{endpoint}?#{query}"
    {oauth_header, _} =
      "put"
      |> OAuther.sign(url, [], credentials)
      |> OAuther.header()

    HTTPoison.put url, xml, [oauth_header, {"Accept", "application/json"}],
      recv_timeout: timeout
  end
end
