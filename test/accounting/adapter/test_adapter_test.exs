defmodule Accounting.TestAdapterTest do
  use ExUnit.Case, async: true
  doctest Accounting.TestAdapter

  alias Accounting.{Account, LineItem, TestAdapter}

  setup do
    {:ok, _} = TestAdapter.start_link([])
    :ok
  end

  describe "fetch_accounts/2" do
    setup do: {:ok, number: "F100"}

    test "without any registered accounts or entries", %{number: number} do
      assert {:ok, accounts} = TestAdapter.fetch_accounts([number], :infinity)
      assert [number] === Map.keys(accounts)
      assert [] === Account.transactions(accounts[number])
    end

    test "with an entry", %{number: number} do
      :ok = TestAdapter.register_account(number, nil, :infinity)
      party = "Chocolate Dynamite LLC"
      item = %LineItem{
        account_number: number,
        amount: 9_000_000_00,
        description: "Wafers",
      }
      :ok = TestAdapter.record_entry(party, ~D[1972-06-19], [item], :infinity)
      assert {:ok, accounts} = TestAdapter.fetch_accounts([number], :infinity)
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
      :ok = TestAdapter.register_account(number, nil, :infinity)
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
      :ok = TestAdapter.record_entry(party, ~D[2000-01-01], [item2], :infinity)
      :ok = TestAdapter.record_entry(party, ~D[1999-12-31], [item1], :infinity)
      assert {:ok, accounts} = TestAdapter.fetch_accounts([number], :infinity)
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

  describe "record_entry/4" do
    test "with an unregistered account" do
      party = "Moonbeams Unlimited"
      date = ~D[1999-12-31]
      items = [
        %LineItem{account_number: "Z100", amount: 0_02, description: "Photons"},
        %LineItem{account_number: "Z100", amount: 0, description: "Free hugs"},
      ]
      assert {:error, :no_such_account} ===
        TestAdapter.record_entry(party, date, items, :infinity)

      for i <- items, do: assert_received {:transaction, ^party, ^date, ^i}
    end

    test "with a registered account" do
      :ok = TestAdapter.register_account("F200", nil, :infinity)
      party = "Leo"
      date = ~D[1093-11-11]
      item = %LineItem{account_number: "F200", amount: 2_09, description: "Air"}
      assert :ok === TestAdapter.record_entry(party, date, [item], :infinity)
      assert_received {:transaction, ^party, ^date, ^item}
    end
  end

  describe "register_account/3" do
    setup do: {:ok, name: "Margus Laroux", number: "F300"}

    test "with a duplicate", %{name: name, number: number} do
      :ok = TestAdapter.register_account(number, "Falogna McZoot", :infinity)
      assert {:error, :duplicate} ===
        TestAdapter.register_account(number, name, :infinity)

      assert_received {:created_account, ^number}
    end

    test "with a new account", %{name: name, number: number} do
      assert :ok === TestAdapter.register_account(number, name, :infinity)
      assert_received {:created_account, ^number}
    end
  end

  test "register_categories/2" do
    categories = [:applewood_smoked, :hickory_smoked, :salt_cured, :sugar_cured]
    assert :ok === TestAdapter.register_categories(categories, :infinity)
    for c <- categories, do: assert_received {:registered_category, ^c}
  end

  test "reset/0" do
    number = "F300"
    name = "Spoons Alridge"
    :ok = TestAdapter.register_account(number, name, :infinity)
    assert :ok === TestAdapter.reset
    assert :ok = TestAdapter.register_account(number, name, :infinity)
  end
end
