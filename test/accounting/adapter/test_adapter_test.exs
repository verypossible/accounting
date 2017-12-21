defmodule Accounting.TestAdapterTest do
  use ExUnit.Case
  doctest Accounting.TestAdapter

  alias Accounting.{Account, Entry, LineItem, TestAdapter}

  setup do
    {:ok, _} = TestAdapter.start_link([])
    :ok
  end

  describe "setup_accounts/3" do
    test "creating new accounts" do
      journal_id = :pink_journal
      accounts = [
        %Account{number: "R1234", description: "Rob Robertson"},
        %Account{number: "T1234", description: "Tom Thompson"},
        %Account{number: "D1234", description: "Don Donaldson"},
        %Account{number: "J1234", description: "James Jameson"},
      ]
      assert :ok ===
        TestAdapter.setup_accounts(journal_id, accounts, :infinity)

      assert_received {:setup_accounts, ^journal_id, ^accounts}
    end

    test "accounts are overwritten" do
      journal_id = :black_journal
      number = "F1234"
      accounts = [
        %Account{number: "R1234", description: "Rob Robertson"},
        %Account{number: "T1234", description: "Tom Thompson"},
        %Account{number: "D1234", description: "Don Donaldson"},
        %Account{number: "J1234", description: "James Jameson"},
      ]
      :ok = TestAdapter.register_account(journal_id, number, nil, :infinity)

      assert {:ok, [number]} === TestAdapter.list_accounts(journal_id, :infinity)
      assert :ok === TestAdapter.setup_accounts(journal_id, accounts, :infinity)
      assert {:ok, ["D1234", "J1234", "R1234", "T1234"]} ===
        TestAdapter.list_accounts(journal_id, :infinity)

      assert_received {:setup_accounts, ^journal_id, ^accounts}
    end
  end

  test "setup_account_conversions/3" do
    journal_id = :black_and_blue_journal
    accounts = [
      %Account{number: "R1234", description: "Rob Robertson"},
      %Account{number: "T1234", description: "Tom Thompson"},
      %Account{number: "D1234", description: "Don Donaldson"},
      %Account{number: "J1234", description: "James Jameson"},
    ]

    assert :ok === TestAdapter.setup_account_conversions(
      journal_id, 1, 2017, accounts, :infinity
    )

    assert_received {
      :setup_account_conversions,
      ^journal_id,
      1,
      2017,
      ^accounts
    }
  end

  describe "list_accounts/2" do
    test "without any registered accounts" do
      assert {:ok, []} === TestAdapter.list_accounts(:blue_journal, :infinity)
    end

    test "with a registered account" do
      journal_id = :black_journal
      number = "F1234"
      :ok = TestAdapter.register_account(journal_id, number, nil, :infinity)

      assert {:ok, [number]} === TestAdapter.list_accounts(journal_id, :infinity)
    end
  end

  describe "fetch_accounts/2" do
    setup do: %{number: "F100"}

    test "without any registered accounts or entries", %{number: number} do
      journal_id = :orange_journal
      assert {:ok, accounts} =
        TestAdapter.fetch_accounts(journal_id, [number], :infinity)

      assert [number] === Map.keys(accounts)
      assert [] === Account.transactions(accounts[number])
    end

    test "with an entry", %{number: number} do
      journal_id = :chartreuse_journal
      :ok = TestAdapter.register_account(journal_id, number, nil, :infinity)
      party = "Chocolate Dynamite LLC"
      item = %LineItem{
        account_number: number,
        amount: 9_000_000_00,
        description: "Wafers",
      }
      entry = Entry.new(party, ~D[1972-06-19], [item])
      :ok = TestAdapter.record_entries(journal_id, [entry], :infinity)
      assert {:ok, accounts} =
        TestAdapter.fetch_accounts(journal_id, [number], :infinity)

      assert [number] === Map.keys(accounts)
      assert [
        %Accounting.AccountTransaction{
          amount: 9_000_000_00,
          date: ~D[1972-06-19],
          description: "Wafers",
        },
      ] = Account.transactions(accounts[number])
    end

    test "with out-of-order entries", %{number: number} do
      journal_id = :lilac_journal
      :ok = TestAdapter.register_account(journal_id, number, nil, :infinity)
      party = "Kobe Buffalo Meat Sticks"
      item1 = %LineItem{
        account_number: number,
        amount: 385_97,
        description: "Mechanically-separated buffalo meat",
      }
      item2 = %LineItem{
        account_number: number,
        amount: 93_939_39,
        description:
          "Campaign to assuage concerns over mechanically-separated buffalo " <>
          "meat",
      }
      entry1 = Entry.new(party, ~D[1999-12-31], [item1])
      entry2 = Entry.new(party, ~D[2000-01-01], [item2])
      :ok = TestAdapter.record_entries(journal_id, [entry2], :infinity)
      :ok = TestAdapter.record_entries(journal_id, [entry1], :infinity)
      assert {:ok, accounts} =
        TestAdapter.fetch_accounts(journal_id, [number], :infinity)

      assert [number] === Map.keys(accounts)
      assert [
        %Accounting.AccountTransaction{
          amount: 38597,
          date: ~D[1999-12-31],
          description: "Mechanically-separated buffalo meat",
        },
        %Accounting.AccountTransaction{amount: 9393939,
          date: ~D[2000-01-01],
          description:
            "Campaign to assuage concerns over mechanically-separated " <>
            "buffalo meat",
        },
      ] = Account.transactions(accounts[number])
    end
  end

  describe "record_entries/3" do
    test "with an entry on an unregistered account" do
      journal_id = :blue_journal
      party = "Moonbeams Unlimited"
      date = ~D[1999-12-31]
      number = "Z100"
      items = [
        %LineItem{account_number: number, amount: 0_02, description: "Photons"},
        %LineItem{account_number: number, amount: 0, description: "Free hugs"},
      ]
      entry = Entry.new(party, date, items)
      assert {:error, :no_such_account} ===
        TestAdapter.record_entries(journal_id, [entry], :infinity)

      assert_received {:recorded_entries, ^journal_id, [^entry]}

      assert {:ok, %{^number => account}} =
        TestAdapter.fetch_accounts(journal_id, [number], :infinity)

      assert [] === Account.transactions(account)
    end

    test "with an entry on a registered account" do
      journal_id = :red_journal
      :ok = TestAdapter.register_account(journal_id, "F200", nil, :infinity)
      party = "Leo"
      date = ~D[1093-11-11]
      number = "F200"
      amount = 2_09
      desc = "Air"
      item = %LineItem{
        account_number: number,
        amount: amount,
        description: desc,
      }
      entry = Entry.new(party, date, [item])
      assert :ok ===
        TestAdapter.record_entries(journal_id, [entry], :infinity)

      assert_received {:recorded_entries, ^journal_id, [^entry]}

      assert {:ok, %{^number => account}} =
        TestAdapter.fetch_accounts(journal_id, [number], :infinity)

      assert [%{amount: ^amount, date: ^date, description: ^desc}] =
        Account.transactions(account)
    end

    test "with multiple entries on registered accounts" do
      journal_id = :aubergine_journal
      number1 = "H300"
      number2 = "X400"
      :ok = TestAdapter.register_account(journal_id, number1, nil, :infinity)
      :ok = TestAdapter.register_account(journal_id, number2, nil, :infinity)
      party1 = "Dillards"
      party2 = "Design Within Reach"
      date1 = ~D[2023-08-15]
      date2 = ~D[1992-02-02]
      amount1 = 1_849_49
      amount2 = 0_38
      desc1 = "Leaves"
      desc2 = "Designer furniture"
      item1 = %LineItem{
        account_number: number1,
        amount: amount1,
        description: desc1,
      }
      item2 = %LineItem{
        account_number: number2,
        amount: amount2,
        description: desc2,
      }
      entries = [
        Entry.new(party1, date1, [item1]),
        Entry.new(party2, date2, [item2]),
      ]
      assert :ok ===
        TestAdapter.record_entries(journal_id, entries, :infinity)

      assert_received {:recorded_entries, ^journal_id, ^entries}

      assert {:ok, %{^number1 => account1, ^number2 => account2}} =
        TestAdapter.fetch_accounts(journal_id, [number1, number2], :infinity)

      assert [%{amount: ^amount1, date: ^date1, description: ^desc1}] =
        Account.transactions(account1)

      assert [%{amount: ^amount2, date: ^date2, description: ^desc2}] =
        Account.transactions(account2)
    end
  end

  describe "register_account/3" do
    setup do: %{name: "Margus Laroux", number: "F300"}

    test "with a duplicate", %{name: name, number: number} do
      journal_id = :yellow_journal
      :ok = TestAdapter.register_account(
        journal_id,
        number,
        "Falogna McZoot",
        :infinity
      )

      assert {:error, :duplicate} ===
        TestAdapter.register_account(journal_id, number, name, :infinity)

      assert_received {:registered_account, ^journal_id, ^number}
    end

    test "with a new account", %{name: name, number: number} do
      journal_id = :pink_journal
      assert :ok ===
        TestAdapter.register_account(journal_id, number, name, :infinity)

      assert_received {:registered_account, ^journal_id, ^number}
    end
  end

  test "register_categories/2" do
    journal_id = :purple_journal
    categories = [:applewood_smoked, :hickory_smoked, :salt_cured, :sugar_cured]
    assert :ok ===
      TestAdapter.register_categories(journal_id, categories, :infinity)

    assert_received {:registered_categories, ^journal_id, ^categories}
  end

  test "reset/0" do
    number = "F300"
    name = "Spoons Alridge"
    journal_id = :periwinkle_journal
    :ok = TestAdapter.register_account(journal_id, number, name, :infinity)
    assert :ok === TestAdapter.reset
    assert :ok =
      TestAdapter.register_account(journal_id, number, name, :infinity)
  end
end
