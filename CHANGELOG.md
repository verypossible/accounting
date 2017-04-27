# Changelog

## v0.5.0 (2017-04-27)

Accounting no longer starts its adapter processes automatically. You can now
start them by calling `Accounting.start_link/1` with configuration options,
including the adapter you wish to use.

In previous Accounting versions, you had to configure the application
environment for this dependency. This was heavy-handed and is no longer
considered a best-practice in Elixir.

## v0.4.2 (2017-04-26)

### 1. Enhancements

  * [XeroAdapter] Fetch new transactions, at most, once per second

## v0.4.1 (2017-04-25)

### 1. Enhancements

  * [XeroAdapter] Return `:rate_limit_exceeded` errors
