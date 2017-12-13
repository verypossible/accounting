defmodule Accounting.Assertions do
  @moduledoc """
  This module contains a set of assertion functions.
  """

  alias Accounting.{Entry, Journal}
  import ExUnit.Assertions, only: [flunk: 1]

  @timeout 100

  @spec assert_registered_categories(Journal.id, [String.t]) :: true | no_return
  def assert_registered_categories(journal_id, categories) do
    receive do
      {:registered_categories, ^journal_id, ^categories} -> true
    after
      @timeout ->
        flunk """
        Categories were not registered:

        #{inspect categories}
        """
    end
  end

  @spec assert_created_account(Journal.id, String.t) :: true | no_return
  def assert_created_account(journal_id, number) do
    receive do
      {:registered_account, ^journal_id, ^number} -> true
    after
      @timeout ->
        flunk "An account was not created with the number '#{number}'."
    end
  end

  @spec assert_recorded_entries(Journal.id, [Entry.t]) :: true | no_return
  def assert_recorded_entries(journal_id, entries) do
    receive do
      {:recorded_entries, ^journal_id, ^entries} -> true
    after
      @timeout ->
        flunk """
        Entries were not recorded:

        #{inspect entries}
        """
    end
  end

  @spec refute_recorded_entries(Journal.id, [Entry.t]) :: true | no_return
  def refute_recorded_entries(journal_id, entries) do
    receive do
      {:recorded_entries, ^journal_id, ^entries} ->
        flunk """
        Unexpected entries were recorded:

        #{inspect entries}
        """
    after
      @timeout -> true
    end
  end
end
