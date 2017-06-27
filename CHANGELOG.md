# Changelog

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
