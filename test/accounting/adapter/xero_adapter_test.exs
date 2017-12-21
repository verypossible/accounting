defmodule Accounting.XeroAdapterTest do
  use ExUnit.Case, async: true

  alias Accounting.{Account, Entry, LineItem, XeroAdapter, XeroView}

  setup do
    journal_id = :oxblood_journal
    bank_id = "Fake Bank Account ID"
    consumer_key = "Fake Consumer Key"
    consumer_secret = "Fake Secret"
    opts = [
      http_client: StubXeroAdapterHTTPClient,
      journal_opts: %{
        journal_id => [
          bank_account_id: bank_id,
          consumer_key: consumer_key,
          consumer_secret: consumer_secret,
        ],
      }
    ]
    {:ok, _} = XeroAdapter.start_link(opts)

    creds = %OAuther.Credentials{
      consumer_key: consumer_key,
      consumer_secret: consumer_secret,
      method: :rsa_sha1,
      token: consumer_key,
      token_secret: nil,
    }
    %{
      bank_id: bank_id,
      creds: creds,
      journal_id: journal_id,
      params: [summarizeErrors: false],
    }
  end

  describe "setup_accounts/3" do
    setup state do
      Map.merge(
        state,
        %{
          accounts: [
            %Account{number: "R1234", description: "Rob Robertson"},
            %Account{number: "T1234", description: "Tom Thompson"},
            %Account{number: "D1234", description: "Don Donaldson"},
            %Account{number: "J1234", description: "James Jameson"},
          ],
        }
      )
    end

    test "returns HTTPoison errors", %{creds: creds, journal_id: journal_id, accounts: accounts} do
      assert {:error, %HTTPoison.Error{reason: HTTPoison.SuperError}} ===
        XeroAdapter.setup_accounts(journal_id, accounts, 1)

      assert_received {:http_post, xml, "Setup", 1, ^creds, []}

      account_assigns = for a <- accounts do
        [number: a.number, name: "#{a.description} - #{a.number}"]
      end
      assert XeroView.render("setup_accounts.xml", accounts: account_assigns) === xml
    end

    test "creates a list of accounts", %{creds: creds, journal_id: journal_id, accounts: accounts} do
      assert :ok === XeroAdapter.setup_accounts(journal_id, accounts, :infinity)

      assert_received {:http_post, xml, "Setup", :infinity, ^creds, []}

      account_assigns = for a <- accounts do
        [number: a.number, name: "#{a.description} - #{a.number}"]
      end
      assert XeroView.render("setup_accounts.xml", accounts: account_assigns) === xml
    end
  end

  describe "setup_account_conversions/3" do
    setup state do
      Map.merge(
        state,
        %{
          accounts: [
            %Account{number: "R1234", conversion_balance: 1_99},
            %Account{number: "T1234", conversion_balance: -2_32},
          ],
        }
      )
    end

    test "returns HTTPoison errors", %{creds: creds, journal_id: journal_id, accounts: accounts} do
      month = 12
      year = 2017

      assert {:error, %HTTPoison.Error{reason: HTTPoison.SuperError}} ===
        XeroAdapter.setup_account_conversions(journal_id, month, year, accounts, 1)

      assert_received {:http_post, xml, "Setup", 1, ^creds, []}

      assigns = [
        month: month,
        year: year,
        accounts: [
          [number: "R1234", conversion_balance: "1.99"],
          [number: "T1233", conversion_balance: "-2.32"],
        ],
      ]
      assert XeroView.render("setup_account_conversions.xml", assigns) === xml
    end

    test "sets the conversion balance for accounts", %{creds: creds, journal_id: journal_id, accounts: accounts} do
      month = 12
      year = 2017

      assert :ok ===
        XeroAdapter.setup_account_conversions(journal_id, month, year, accounts, :infinity)

      assert_received {:http_post, xml, "Setup", :infinity, ^creds, []}

      assigns = [
        month: month,
        year: year,
        accounts: [
          [number: "R1234", conversion_balance: "1.99"],
          [number: "T1233", conversion_balance: "-2.32"],
        ],
      ]
      assert XeroView.render("setup_account_conversions.xml", assigns) === xml
    end
  end

  describe "list_accounts/2" do
    test "returns HTTPoison errors", %{creds: creds, journal_id: journal_id} do
      assert {:error, %HTTPoison.Error{reason: HTTPoison.SuperError}} ===
        XeroAdapter.list_accounts(journal_id, 1)

      assert_received {:http_get, "Accounts", 1, ^creds, []}
    end

    test "returns a list of account numbers", %{journal_id: journal_id} do
      assert {:ok, ["F1234", "G1234"]} ===
        XeroAdapter.list_accounts(journal_id, :infinity)
    end
  end

  describe "record_entries/3" do
    test "returns HTTPoison errors", %{bank_id: bank_id, creds: creds, journal_id: journal_id, params: params} do
      item = %LineItem{account_number: "B42", amount: 4_99, description: "Soap"}
      entry = Entry.new("Bill", ~D[1937-02-26], [item])
      assert {:error, %HTTPoison.Error{reason: HTTPoison.SuperError}} ===
        XeroAdapter.record_entries(journal_id, [entry], 1)

      assert_received {:http_put, xml, "BankTransactions", 1, ^creds, ^params}
      refute_received {:http_put, _, "Invoices", _, _, _}

      assigns = [bank_account_id: bank_id, entries: [entry]]
      assert XeroView.render("bank_transactions.xml", assigns) === xml
    end

    test "returns non-200s as errors", %{bank_id: bank_id, creds: creds, journal_id: journal_id, params: params} do
      item = %LineItem{account_number: "B43", amount: 5_99, description: "Soup"}
      entry = Entry.new("Bob", ~D[1937-02-25], [item])
      assert {:error, %HTTPoison.Response{status_code: 400, headers: []}} ===
        XeroAdapter.record_entries(journal_id, [entry], 2)

      assert_received {:http_put, xml, "BankTransactions", 2, ^creds, ^params}
      refute_received {:http_put, _, "Invoices", _, _, _}

      assigns = [bank_account_id: bank_id, entries: [entry]]
      assert XeroView.render("bank_transactions.xml", assigns) === xml
    end

    test "with a non-zero entry", %{bank_id: bank_id, creds: creds, journal_id: journal_id, params: params} do
      item = %LineItem{account_number: "F200", amount: 2_09, description: "Air"}
      entry = Entry.new("Leo", ~D[1093-11-11], [item])
      assert :ok ===
        XeroAdapter.record_entries(journal_id, [entry], :infinity)

      assert_received {
        :http_put,
        xml,
        "BankTransactions",
        :infinity,
        ^creds,
        ^params,
      }
      refute_received {:http_put, _, "Invoices", _, _, _}

      assigns = [bank_account_id: bank_id, entries: [entry]]
      assert XeroView.render("bank_transactions.xml", assigns) === xml
    end

    test "with a net-zero entry", %{creds: creds, journal_id: journal_id, params: params} do
      item1 = %LineItem{account_number: "F2", amount: 2_09, description: "Air"}
      item2 = %LineItem{account_number: "G2", amount: -2_09, description: "T"}
      entry = Entry.new("Leo", ~D[1093-11-11], [item1, item2])
      assert :ok ===
        XeroAdapter.record_entries(journal_id, [entry], :infinity)

      assert_received {:http_put, xml, "Invoices", :infinity, ^creds, ^params}
      refute_received {:http_put, _, "BankTransactions", _, _, _}

      assigns = [entries: [entry]]
      assert XeroView.render("invoices.xml", assigns) === xml
    end

    test "with multiple non-zero entries", %{bank_id: bank_id, creds: creds, journal_id: journal_id, params: params} do
      item1 = %LineItem{account_number: "F20", amount: 2_09, description: "Air"}
      entry1 = Entry.new("Leo", ~D[1093-11-11], [item1])
      item2 = %LineItem{account_number: "G2", amount: 4_10, description: "Flow"}
      entry2 = Entry.new("Liz", ~D[1094-10-10], [item2])
      assert :ok ===
        XeroAdapter.record_entries(journal_id, [entry1, entry2], :infinity)

      assert_received {
        :http_put,
        xml,
        "BankTransactions",
        :infinity,
        ^creds,
        ^params,
      }
      refute_received {:http_put, _, "Invoices", _, _, _}

      assigns = [bank_account_id: bank_id, entries: [entry1, entry2]]
      assert XeroView.render("bank_transactions.xml", assigns) === xml
    end

    test "with multiple net-zero entries", %{creds: creds, journal_id: journal_id, params: params} do
      items1 = [
        %LineItem{account_number: "F200", amount: 2_09, description: "Air"},
        %LineItem{account_number: "A200", amount: -2_09, description: "Jordan"},
      ]
      entry1 = Entry.new("Leo", ~D[1093-11-11], items1)
      items2 = [
        %LineItem{account_number: "G201", amount: 4_10, description: "Air"},
        %LineItem{account_number: "B201", amount: -4_10, description: "Force"},
      ]
      entry2 = Entry.new("Liz", ~D[1094-10-10], items2)
      assert :ok ===
        XeroAdapter.record_entries(journal_id, [entry1, entry2], :infinity)

      assert_received {:http_put, xml, "Invoices", :infinity, ^creds, ^params}
      refute_received {:http_put, _, "BankTransactions", _, _, _}

      assigns = [entries: [entry1, entry2]]
      assert XeroView.render("invoices.xml", assigns) === xml
    end

    test "with a mix of non-zero and net-zero entries", %{journal_id: journal_id} do
      nonzero_item = %LineItem{
        account_number: "K30",
        amount: 4_23,
        description: "Ah Yeah",
      }
      nonzero_entry = Entry.new("Leo", ~D[1393-03-11], [nonzero_item])
      zero_items = [
        %LineItem{account_number: "F200", amount: 2_09, description: "Air"},
        %LineItem{account_number: "A200", amount: -2_09, description: "Jordan"},
      ]
      zero_entry = Entry.new("Leo", ~D[1093-11-11], zero_items)
      entries = [zero_entry, nonzero_entry]

      assert {:error, :mixed_entries} ===
        XeroAdapter.record_entries(journal_id, entries, :infinity)

      refute_received {:http_put, _, "BankTransactions", _, _, _}
      refute_received {:http_put, _, "Invoices", _, _, _}
    end

    test "with invalid non-zero entries", %{journal_id: journal_id} do
      item1 = %LineItem{account_number: "E18", amount: 4, description: "Salt"}
      item2 = %LineItem{account_number: "P46", amount: 3_03, description: "Art"}
      item3 = %LineItem{account_number: "Z38", amount: 1, description: "Cults"}
      item4 = %LineItem{account_number: "H92", amount: 24, description: "Lamp"}
      entry1 = Entry.new("Lemons", ~D[1999-02-16], [item1])
      entry2 = Entry.new("Shoe salesman", ~D[1630-12-08], [item2])
      entry3 = Entry.new("Yogurt", ~D[2004-11-20], [item3])
      entry4 = Entry.new("Boat salesman", ~D[1847-05-19], [item4])
      entries = [entry1, entry2, entry3, entry4]
      error1 = %Entry.Error{
        entry: entry2,
        errors: ["Something terrible has occurred!"],
      }
      error2 = %Entry.Error{
        entry: entry4,
        errors: ["The sky is falling!", "Fix dis now!", "I give up."],
      }
      assert {:error, [error1, error2]} ===
        XeroAdapter.record_entries(journal_id, entries, 3)
    end

    test "with invalid net-zero entries", %{journal_id: journal_id} do
      items1 = [
        %LineItem{account_number: "E18", amount: 4, description: "Salt"},
        %LineItem{account_number: "E18", amount: -4, description: "Salt"},
      ]
      items2 = [
        %LineItem{account_number: "P46", amount: 3_03, description: "Art"},
        %LineItem{account_number: "P46", amount: -3_03, description: "Art"},
      ]
      items3 = [
        %LineItem{account_number: "Z38", amount: 1, description: "Cults"},
        %LineItem{account_number: "Z38", amount: -1, description: "Cults"},
      ]
      items4 = [
        %LineItem{account_number: "H92", amount: 24, description: "Lamp"},
        %LineItem{account_number: "H92", amount: -24, description: "Lamp"},
      ]
      entry1 = Entry.new("Lemons", ~D[1999-02-16], items1)
      entry2 = Entry.new("Shoe salesman", ~D[1630-12-08], items2)
      entry3 = Entry.new("Yogurt", ~D[2004-11-20], items3)
      entry4 = Entry.new("Boat salesman", ~D[1847-05-19], items4)
      entries = [entry1, entry2, entry3, entry4]
      error1 = %Entry.Error{
        entry: entry2,
        errors: ["Something terrible has occurred!"],
      }
      error2 = %Entry.Error{
        entry: entry4,
        errors: ["The sky is falling!", "Fix dis now!", "I give up."],
      }
      assert {:error, [error1, error2]} ===
        XeroAdapter.record_entries(journal_id, entries, 3)
    end
  end
end
