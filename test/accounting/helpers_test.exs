defmodule Accounting.HelpersTest do
  use ExUnit.Case, async: true
  doctest Accounting.Helpers

  alias Accounting.{AccountTransaction, Helpers}

  test "sort_transactions/1" do
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
