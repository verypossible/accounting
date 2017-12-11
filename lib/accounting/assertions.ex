defmodule Accounting.Assertions do
  @moduledoc """
  This module contains a set of assertion functions.
  """

  alias Accounting.Journal
  import ExUnit.Assertions, only: [flunk: 1]

  @timeout 100

  @spec assert_registered_category(Journal.id, String.t) :: true | no_return
  def assert_registered_category(journal_id, category) do
    receive do
      {:registered_category, ^journal_id, ^category} -> true
    after
      @timeout ->
        flunk "Category '#{category}' was not registered."
    end
  end

  @spec assert_created_account(Journal.id, String.t) :: true | no_return
  def assert_created_account(journal_id, number) do
    receive do
      {:created_account, ^journal_id, ^number} -> true
    after
      @timeout ->
        flunk "An account was not created with the number '#{number}'."
    end
  end

  @spec assert_transaction_with_line_item(Journal.id, String.t, Date.t, [Accounting.LineItem.t]) :: true | no_return
  def assert_transaction_with_line_item(journal_id, party, date, line_item) do
    receive do
      {:transaction, ^journal_id, ^party, ^date, ^line_item} -> true
    after
      @timeout ->
        flunk """
        Transaction did not occur with '#{party}' on #{date} with the line item:

        #{inspect line_item}
        """
    end
  end

  @spec refute_transaction(Journal.id, String.t, Date.t) :: true | no_return
  def refute_transaction(journal_id, from, date) do
    receive do
      {:transaction, ^journal_id, ^from, ^date, _} ->
        flunk "Unexpected transaction occurred."
    after
      @timeout -> true
    end
  end
end
