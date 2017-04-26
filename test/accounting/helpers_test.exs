defmodule Accounting.HelpersTest do
  use ExUnit.Case, async: true
  doctest Accounting.Helpers

  alias Accounting.{AccountTransaction, Helpers}

  describe "calculate_balance/1" do
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
      assert 0 === Helpers.calculate_balance([])
    end

    test "with a credit", %{credit: credit} do
      assert 55_55 === Helpers.calculate_balance([credit])
    end

    test "with a debit", %{debit: debit} do
      assert -42_00 === Helpers.calculate_balance([debit])
    end

    test "with a credit and a debit", %{credit: credit, debit: debit} do
      assert 13_55 === Helpers.calculate_balance([credit, debit])
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
      assert 11_116_83 ===
        Helpers.calculate_balance(transactions)
    end
  end

  describe "calculate_balance!/2" do
    setup do
      transaction = %AccountTransaction{amount: 55_55, date: ~D[1970-01-01]}
      {:ok, transaction: transaction}
    end

    test "without any transactions" do
      assert 0 === Helpers.calculate_balance!([], ~D[1970-01-01])
    end

    test "with a transaction before the date", %{transaction: transaction} do
      assert 55_55 === Helpers.calculate_balance!([transaction], ~D[1970-01-02])
    end

    test "with a transaction on the date", %{transaction: transaction} do
      assert 55_55 === Helpers.calculate_balance!([transaction], ~D[1970-01-01])
    end

    test "with a transaction after the date", %{transaction: transaction} do
      assert 0 === Helpers.calculate_balance!([transaction], ~D[1969-12-31])
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
      assert 1_152_83 ===
        Helpers.calculate_balance!(transactions, ~D[2000-04-12])
    end

    test "with unsorted transactions" do
      transactions = [
        %AccountTransaction{amount: 100_00, date: ~D[1871-03-18]},
        %AccountTransaction{amount: 100_00, date: ~D[2000-04-05]},
        %AccountTransaction{amount: -50_00, date: ~D[1970-01-01]},
      ]
      assert_raise ArgumentError, fn ->
        Helpers.calculate_balance!(transactions, ~D[1970-01-01])
      end
    end
  end

  describe "calculate_ADB!/3" do
    test "without any transactions" do
      assert 0 === Helpers.calculate_ADB!([], ~D[2000-04-01], ~D[2000-04-30])
    end

    test "with a transaction after the end date" do
      transaction = %AccountTransaction{
        amount: 100_00,
        date: ~D[2000-05-01],
        description: "out of bounds",
      }
      assert 0 ===
        Helpers.calculate_ADB!([transaction], ~D[2000-04-01], ~D[2000-04-30])
    end

    test "with a transaction before the start date" do
      transaction = %AccountTransaction{
        amount: 100_00,
        date: ~D[1871-03-18],
        description: "starting balance",
      }
      assert 100_00 ===
        Helpers.calculate_ADB!([transaction], ~D[2000-04-01], ~D[2000-04-30])
    end

    test "with a transaction right between the start and end dates" do
      transaction = %AccountTransaction{
        amount: 100_00,
        date: ~D[2000-04-16],
        description: "midway",
      }
      assert 50_00 ===
        Helpers.calculate_ADB!([transaction], ~D[2000-04-01], ~D[2000-04-30])
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
      assert 1_271_78 ===
        Helpers.calculate_ADB!(transactions, ~D[2000-04-01], ~D[2000-04-30])
    end

    test "with unsorted transactions" do
      transactions = [
        %AccountTransaction{amount: 100_00, date: ~D[1871-03-18]},
        %AccountTransaction{amount: 100_00, date: ~D[2000-04-05]},
        %AccountTransaction{amount: -50_00, date: ~D[1970-01-01]},
      ]
      assert_raise ArgumentError, fn ->
        Helpers.calculate_ADB!(transactions, ~D[2000-04-01], ~D[2000-04-30])
      end
    end
  end

  describe "sort_transactions/1" do
    test "with a large assortment of unsorted transactions" do
      transactions = [
        %AccountTransaction{date: ~D[2000-04-17]},
        %AccountTransaction{date: ~D[2000-04-25]},
        %AccountTransaction{date: ~D[2000-04-06]},
        %AccountTransaction{date: ~D[2000-04-11]},
        %AccountTransaction{date: ~D[2000-04-13]},
        %AccountTransaction{date: ~D[2017-02-02]},
        %AccountTransaction{date: ~D[2000-04-25]},
        %AccountTransaction{date: ~D[2000-04-05]},
        %AccountTransaction{date: ~D[1970-01-01]},
        %AccountTransaction{date: ~D[2000-04-12]},
        %AccountTransaction{date: ~D[2000-05-01]},
        %AccountTransaction{date: ~D[1871-03-18]},
        %AccountTransaction{date: ~D[1970-01-01]},
        %AccountTransaction{date: ~D[2016-10-17]},
        %AccountTransaction{date: ~D[2000-04-25]},
        %AccountTransaction{date: ~D[2000-04-30]},
        %AccountTransaction{date: ~D[2000-04-12]},
      ]

      assert [
        %AccountTransaction{date: ~D[1871-03-18]},
        %AccountTransaction{date: ~D[1970-01-01]},
        %AccountTransaction{date: ~D[1970-01-01]},
        %AccountTransaction{date: ~D[2000-04-05]},
        %AccountTransaction{date: ~D[2000-04-06]},
        %AccountTransaction{date: ~D[2000-04-11]},
        %AccountTransaction{date: ~D[2000-04-12]},
        %AccountTransaction{date: ~D[2000-04-12]},
        %AccountTransaction{date: ~D[2000-04-13]},
        %AccountTransaction{date: ~D[2000-04-17]},
        %AccountTransaction{date: ~D[2000-04-25]},
        %AccountTransaction{date: ~D[2000-04-25]},
        %AccountTransaction{date: ~D[2000-04-25]},
        %AccountTransaction{date: ~D[2000-04-30]},
        %AccountTransaction{date: ~D[2000-05-01]},
        %AccountTransaction{date: ~D[2016-10-17]},
        %AccountTransaction{date: ~D[2017-02-02]},
      ] === Helpers.sort_transactions(transactions)
    end
  end
end
