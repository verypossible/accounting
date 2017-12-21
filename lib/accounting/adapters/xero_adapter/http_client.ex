defmodule Accounting.XeroAdapter.HTTPClient do
  @moduledoc """
  A behaviour module for implementing a Xero HTTP client.
  """

  @type credentials :: %OAuther.Credentials{}
  @type endpoint :: String.t
  @type params :: keyword
  @type xml :: String.t

  @callback get(endpoint, timeout, credentials) :: {:ok, HTTPoison.Response.t} | {:error, HTTPoison.Error.t}
  @callback get(endpoint, timeout, credentials, params) :: {:ok, HTTPoison.Response.t} | {:error, HTTPoison.Error.t}
  @callback put(xml, endpoint, timeout, credentials) :: {:ok, HTTPoison.Response.t | HTTPoison.AsyncResponse.t} | {:error, HTTPoison.Error.t}
  @callback put(xml, endpoint, timeout, credentials, params) :: {:ok, HTTPoison.Response.t | HTTPoison.AsyncResponse.t} | {:error, HTTPoison.Error.t}
  @callback post(xml, endpoint, timeout, credentials) :: {:ok, HTTPoison.Response.t | HTTPoison.AsyncResponse.t} | {:error, HTTPoison.Error.t}
  @callback post(xml, endpoint, timeout, credentials, params) :: {:ok, HTTPoison.Response.t | HTTPoison.AsyncResponse.t} | {:error, HTTPoison.Error.t}
end
