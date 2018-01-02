# Changelog

## v0.10.5 (2018-1-2)

### 1. Enhancements

  * [Assertions] Add `assert_recorded_invoices/2`
  * [Assertions] Add `refute_recorded_invoices/2`
  * [Adapter] Add `record_invoices/3` callback
  * [Journal] Add `record_invoices/2-3`
  * [XeroAdapter] Add `record_invoices/3`

## v0.10.4 (2017-12-22)

### 1. Enhancements

  * [Assertions] Add `assert_setup_accounts/2`
  * [Assertions] Add `refute_setup_accounts/2`
  * [Assertions] Add `assert_setup_account_conversions/4`
  * [Assertions] Add `refute_setup_account_conversions/4`
  * [Account] Add `Account.setup` type.
  * [Account] Add `:description` and `:conversion_balance` fields to struct.
  * [Adapter] Add `setup_accounts/3` callback
  * [Adapter] Add `setup_account_conversions/5` callback
  * [Journal] Add `setup_accounts/2-3`
  * [Journal] Add `setup_account_conversions/4-5`
  * [XeroAdapter] Add `setup_accounts/3`
  * [XeroAdapter] Add `setup_account_conversions/5`
  * [XeroAdapter.HTTPClient] Add `post/4-5` callback
  * [XeroAdapter.DefaultHTTPClient] Add `post/4-5` callback

## v0.10.3 (2017-12-19)

### 1. Enhancements

  * [Assertions] Add `refute_account_created/2`

## v0.10.2 (2017-12-19)

### 1. Enhancements

  * [Journal] Add `list_accounts/2`

## v0.10.1 (2017-12-15)

### 1. Enhancements

  * [Assertions] Add `refute_registered_categories/2`
  * [Entry] Update Inspect implementation to output line_items.

## v0.10.0 (2017-12-13)

### 1. Enhancements

  * [Assertions] Add `assert_registered_categories/2`
  * [Assertions] Add `assert_recorded_entries/2`

### 2. Removals

  * [Assertions] `assert_registered_category/2`, in favor of `assert_registered_categories/2`
  * [Assertions] `assert_transaction_with_line_item/4`, in favor of `assert_recorded_entries/2`

## v0.9.0 (2017-12-11)

### 1. Enhancements

  * Add Entry type
  * Add HTTPClient behaviour
  * [Adapter] Add `record_entries/3` callback
  * [Entry] Add Error type
  * [Journal] Add `record_entries/2-3`
  * [XeroAdapter] Add DefaultHTTPClient module

### 2. Removals

  * [Adapter] `record_entry/5` callback, in favor of `record_entries/3`
  * [Journal] `record_entry/4-5`, in favor of `record_entries/2-3`

## v0.8.0 (2017-11-14)

This release facilitates handling multiple journals. Most `Journal` function calls now require a journal id.

### 1. Enhancements

  * [Adapter] Add `fetch_accounts/3` callback
  * [Adapter] Add `record_entry/4-5` callback
  * [Adapter] Add `register_account/3-4` callback
  * [Adapter] Add `register_categories/2-3` callback
  * [Assertions] Add `assert_registered_category/2`
  * [Assertions] Add `assert_created_account/2`
  * [Assertions] Add `assert_transaction_with_line_item/4`
  * [Assertions] Add `refute_transaction/3`
  * [Journal] Add id type
  * [Journal] Add `fetch_accounts/2-3`
  * [Journal] Add `record_entry/4-5`
  * [Journal] Add `register_account/3-4`
  * [Journal] Add `register_categories/2-3`
  * [Journal] Allow `start_link/1` opts to provide `journal_opts` key which is passed to the adapter
  * [XeroAdapter] Expect `start_link/1` to receive a map of journal options with `Journal.id/0` keys and keyword list values with required `:bank_account_id`, `:consumer_key`, and `:consumer_secret` keys

### 2. Removals

  * [Adapter] `fetch_accounts/2` callback, in favor of `fetch_accounts/3`
  * [Adapter] `record_entry/3-4` callback, in favor of `record_entry/4-5`
  * [Adapter] `register_account/2-3` callback, in favor of `register_account/3-4`
  * [Adapter] `register_categories/1-2` callback, in favor of `register_categories/2-3`
  * [Assertions] `assert_registered_category/1`, in favor of `assert_registered_category/2`
  * [Assertions] `assert_created_account/1`, in favor of `assert_created_account/2`
  * [Assertions] `assert_transaction_with_line_item/3`, in favor of `assert_transaction_with_line_item/4`
  * [Assertions] `refute_transaction/2`, in favor of `refute_transaction/3`
  * [Journal] `fetch_accounts/1-2`, in favor of `fetch_accounts/2-3`
  * [Journal] `record_entry/3-4`, in favor of `record_entry/4-5`
  * [Journal] `register_account/2-3`, in favor of `register_account/3-4`
  * [Journal] `register_categories/1-2`, in favor of `register_categories/2-3`
  * [XeroAdapter] `start_link/1` keyword list argument, in favor of a map with `Journal.id/0` keys and keyword list values with required `:bank_account_id`, `:consumer_key`, and `:consumer_secret` keys

## v0.7.1 (2017-08-24)

### 1. Enhancements

  * Add new types

### 2. Bug fixes

  * [XeroAdapter] Return accounts from `fetch_accounts/2` for accounts that have
    not been registered

## v0.7.0 (2017-08-21)

This release radically alters the API. It serves to separate value functions
from effect functions. The new `Journal` module provides functions for reading
to and writing from the journal. On success, `Journal.fetch_accounts/1-2`
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
  * [Journal] Add `fetch_accounts/1-2`
  * [Journal] Add `record_entry/3-4`
  * [Journal] Add `register_account/2-3`
  * [Journal] Add `register_categories/1-2`
  * [Journal] Add `start_link/1`

### 2. Removals

  * `create_account/2-3`, in favor of `Journal.register_account/2-3`
  * `fetch_account_transactions/2-3`
  * `fetch_ADB/3-4`
  * `fetch_balance/1-2`
  * `fetch_balance_on_date/2-3`
  * `register_categories/1-2`, in favor of `Journal.register_categories/1-2`
  * `transact/3-4`, in favor of `Journal.record_entry/3-4`
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

### 2. Removals

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
