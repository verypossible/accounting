defmodule Accounting.EntryTest do
  use ExUnit.Case, async: true
  doctest Accounting.Entry

  alias Accounting.{Entry, LineItem}

  test "new/3" do
    party = "solo cups"
    date = ~D[1938-12-12]
    line_items = [
      %LineItem{account_number: "n", amount: 2, description: "one"},
      %LineItem{account_number: "n", amount: 3, description: "two"},
    ]

    assert %Entry{} = entry = Entry.new(party, date, line_items)
    assert party === entry.party
    assert date === entry.date
    assert line_items === entry.line_items
    assert 5 === entry.total
  end

  test "Inspect implementation" do
    party = "ah yeah williams"
    date = ~D[1934-10-10]
    line_items = [
      %LineItem{account_number: "n", amount: 3, description: "three"},
      %LineItem{account_number: "n", amount: 4, description: "four"},
    ]
    assert "#Entry<party: #{party}, date: ~D[1934-10-10], total: 7>" ===
      inspect(Entry.new(party, date, line_items))
  end
end
