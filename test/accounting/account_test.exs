defmodule Accounting.AccountTest do
  use ExUnit.Case, async: true
  doctest Accounting.Account

  alias Accounting.{Account, AccountTransaction}

  describe "average_daily_balance/3" do
    setup do: {:ok, date_range: Date.range(~D[2000-04-01], ~D[2000-04-30])}

    test "without any transactions", %{date_range: date_range} do
      account = %Account{}
      assert 0 === Account.average_daily_balance(account, date_range)
    end

    test "with a transaction after the end date", %{date_range: date_range} do
      transaction = %AccountTransaction{
        amount: 100_00,
        date: ~D[2000-05-01],
        description: "out of bounds",
      }
      account = %Account{transactions: [transaction]}
      assert 0 === Account.average_daily_balance(account, date_range)
    end

    test "with a transaction before the start date", %{date_range: date_range} do
      transaction = %AccountTransaction{
        amount: 100_00,
        date: ~D[1871-03-18],
        description: "starting balance",
      }
      account = %Account{transactions: [transaction]}
      assert 100_00 === Account.average_daily_balance(account, date_range)
    end

    test "with a transaction right between the start and end dates", %{date_range: date_range} do
      transaction = %AccountTransaction{
        amount: 100_00,
        date: ~D[2000-04-16],
        description: "midway",
      }
      account = %Account{transactions: [transaction]}
      assert 50_00 === Account.average_daily_balance(account, date_range)
    end

    test "with a large assortment of sorted transactions", %{date_range: date_range} do
      transactions = [
        %AccountTransaction{amount:    100_00, date: ~D[1871-03-18]},
        %AccountTransaction{amount:    -50_00, date: ~D[1970-01-01]},
        %AccountTransaction{amount:  1_000_00, date: ~D[1970-01-01]},
        %AccountTransaction{amount:    100_00, date: ~D[2000-04-05]},
        %AccountTransaction{amount:    -40_00, date: ~D[2000-04-06]},
        %AccountTransaction{amount:     40_00, date: ~D[2000-04-11]},
        %AccountTransaction{amount:      3_33, date: ~D[2000-04-12]},
        %AccountTransaction{amount:       -50, date: ~D[2000-04-12]},
        %AccountTransaction{amount:   -500_00, date: ~D[2000-04-13]},
        %AccountTransaction{amount:    123_45, date: ~D[2000-04-17]},
        %AccountTransaction{amount:    900_99, date: ~D[2000-04-25]},
        %AccountTransaction{amount:     10_25, date: ~D[2000-04-25]},
        %AccountTransaction{amount:   -666_00, date: ~D[2000-04-25]},
        %AccountTransaction{amount: 10_000_00, date: ~D[2000-04-30]},
        %AccountTransaction{amount:    100_00, date: ~D[2000-05-01]},
        %AccountTransaction{amount:     -4_99, date: ~D[2016-10-17]},
        %AccountTransaction{amount:        30, date: ~D[2017-02-02]},
      ]
      account = %Account{transactions: transactions}
      assert 1_271_78 === Account.average_daily_balance(account, date_range)
    end
  end

  describe "balance/1" do
    setup do
      credit = %AccountTransaction{
        amount: 55_55,
        date: ~D[1970-01-01],
        description: "credit",
      }
      debit = %AccountTransaction{
        amount: -42_00,
        date: ~D[1980-02-02],
        description: "debit",
      }
      {:ok, credit: credit, debit: debit}
    end

    test "without any transactions" do
      assert 0 === Account.balance(%Account{})
    end

    test "with a credit", %{credit: credit} do
      assert 55_55 === Account.balance(%Account{transactions: [credit]})
    end

    test "with a debit", %{debit: debit} do
      assert -42_00 === Account.balance(%Account{transactions: [debit]})
    end

    test "with a credit and a debit", %{credit: credit, debit: debit} do
      assert 13_55 === Account.balance(%Account{transactions: [credit, debit]})
    end

    test "with a large assortment of transactions" do
      transactions = [
        %AccountTransaction{amount:    123_45},
        %AccountTransaction{amount:   -666_00},
        %AccountTransaction{amount:    -40_00},
        %AccountTransaction{amount:     40_00},
        %AccountTransaction{amount:   -500_00},
        %AccountTransaction{amount:        30},
        %AccountTransaction{amount:     10_25},
        %AccountTransaction{amount:    100_00},
        %AccountTransaction{amount:  1_000_00},
        %AccountTransaction{amount:      3_33},
        %AccountTransaction{amount:    100_00},
        %AccountTransaction{amount:    100_00},
        %AccountTransaction{amount:    -50_00},
        %AccountTransaction{amount:     -4_99},
        %AccountTransaction{amount:    900_99},
        %AccountTransaction{amount: 10_000_00},
        %AccountTransaction{amount:       -50},
      ]
      assert 11_116_83 === Account.balance(%Account{transactions: transactions})
    end
  end

  describe "balance_on_date/2" do
    setup do
      transaction = %AccountTransaction{amount: 55_55, date: ~D[1970-01-01]}
      {:ok, transaction: transaction}
    end

    test "without any transactions" do
      assert 0 === Account.balance_on_date(%Account{}, ~D[1970-01-01])
    end

    test "with a transaction before the date", %{transaction: transaction} do
      account = %Account{transactions: [transaction]}
      assert 55_55 === Account.balance_on_date(account, ~D[1970-01-02])
    end

    test "with a transaction on the date", %{transaction: transaction} do
      account = %Account{transactions: [transaction]}
      assert 55_55 === Account.balance_on_date(account, ~D[1970-01-01])
    end

    test "with a transaction after the date", %{transaction: transaction} do
      account = %Account{transactions: [transaction]}
      assert 0 === Account.balance_on_date(account, ~D[1969-12-31])
    end

    test "with a large assortment of sorted transactions" do
      transactions = [
        %AccountTransaction{amount:    100_00, date: ~D[1871-03-18]},
        %AccountTransaction{amount:    -50_00, date: ~D[1970-01-01]},
        %AccountTransaction{amount:  1_000_00, date: ~D[1970-01-01]},
        %AccountTransaction{amount:    100_00, date: ~D[2000-04-05]},
        %AccountTransaction{amount:    -40_00, date: ~D[2000-04-06]},
        %AccountTransaction{amount:     40_00, date: ~D[2000-04-11]},
        %AccountTransaction{amount:      3_33, date: ~D[2000-04-12]},
        %AccountTransaction{amount:       -50, date: ~D[2000-04-12]},
        %AccountTransaction{amount:   -500_00, date: ~D[2000-04-13]},
        %AccountTransaction{amount:    123_45, date: ~D[2000-04-17]},
        %AccountTransaction{amount:    900_99, date: ~D[2000-04-25]},
        %AccountTransaction{amount:     10_25, date: ~D[2000-04-25]},
        %AccountTransaction{amount:   -666_00, date: ~D[2000-04-25]},
        %AccountTransaction{amount: 10_000_00, date: ~D[2000-04-30]},
        %AccountTransaction{amount:    100_00, date: ~D[2000-05-01]},
        %AccountTransaction{amount:     -4_99, date: ~D[2016-10-17]},
        %AccountTransaction{amount:        30, date: ~D[2017-02-02]},
      ]
      account = %Account{transactions: transactions}
      assert 1_152_83 === Account.balance_on_date(account, ~D[2000-04-12])
    end
  end

  test "transactions/1" do
    transactions = [
      %AccountTransaction{amount:    3_33, date: ~D[2000-04-12]},
      %AccountTransaction{amount:     -50, date: ~D[2000-04-12]},
      %AccountTransaction{amount: -500_00, date: ~D[2000-04-13]},
    ]
    account = %Account{transactions: transactions}
    assert transactions === Account.transactions(account)
  end
end
