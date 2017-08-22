# Changelog

## v0.7.0 (2017-08-21)

This release radically alters the API. It serves to separate value functions
from effect functions. The new `Journal` module provides functions for reading
to and writing from the journal. On success, `Journal.fetch_accounts/1–2`
returns accounts. The new `Account` module provides functions for obtaining
amounts and transactions from these accounts.

One of the major benefits of this separation is the ability to read from the
journal once while obtaining multiple amounts from the returned accounts.

### 1. Enhancements

  * Add Account type
  * Add Journal module
  * [Account] Add `average_daily_balance/2`
  * [Account] Add `balance/1`
  * [Account] Add `balance_on_date/2`
  * [Account] Add `transactions/1`
  * [Adapter] Add `child_spec/1` callback
  * [Adapter] Add `fetch_accounts/2` callback
  * [Adapter] Add `record_entry/4` callback
  * [Adapter] Add `register_account/3` callback
  * [Journal] Add `child_spec/1`
  * [Journal] Add `fetch_accounts/1–2`
  * [Journal] Add `record_entry/3–4`
  * [Journal] Add `register_account/2–3`
  * [Journal] Add `register_categories/1–2`
  * [Journal] Add `start_link/1`

### 2. Deprecations

  * `create_account/2–3`, in favor of `Journal.register_account/2–3`
  * `fetch_account_transactions/2–3`
  * `fetch_ADB/3–4`
  * `fetch_balance/1–2`
  * `fetch_balance_on_date/2–3`
  * `register_categories/1–2`, in favor of `Journal.register_categories/1–2`
  * `transact/3–4`, in favor of `Journal.record_entry/3–4`
  * [Adapter] `fetch_account_transactions/2` callback, in favor of
    `fetch_accounts/2`
  * [Adapter] `transact/4` callback, in favor of `record_entry/4`
  * [Adapter] `create_account/3` callback, in favor of `register_account/3`
  * [Helpers] `calculate_balance/1`
  * [Helpers] `calculate_balance!/2`
  * [Helpers] `calculate_ADB!/3`

## v0.6.0 (2017-06-27)

### 1. Enhancements

  * Add `transact/4`
  * [Assertions] Add `assert_transaction_with_line_item/3`
  * [Assertions] Add `refute_transaction_with_line_item/3`

### 2. Deprecations

  * `receive_money/4`, in favor of `transact/4`
  * `spend_money/4`
  * [Assertions] `assert_received_money_with_line_item/3`, in favor of
    `assert_transaction_with_line_item/3`
  * [Assertions] `refute_received_money_with_line_item/2`, in favor of
    `refute_transaction_with_line_item/2`
  * [Assertions] `assert_spent_money_with_line_item/3`
  * [Assertions] `refute_spent_money_with_line_item/2`


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
