defmodule Accounting.Assertions do
  import ExUnit.Assertions, only: [flunk: 1]

  @timeout 100

  @spec assert_registered_category(String.t) :: true | no_return
  def assert_registered_category(category) do
    receive do
      {:registered_category, ^category} -> true
    after
      @timeout ->
        flunk "Category '#{category}' was not registered."
    end
  end

  @spec assert_created_account(String.t) :: true | no_return
  def assert_created_account(number) do
    receive do
      {:created_account, ^number} -> true
    after
      @timeout ->
        flunk "An account was not created with the number '#{number}'."
    end
  end

  @spec assert_transaction_with_line_item(String.t, Date.t, [Accounting.LineItem.t]) :: true | no_return
  def assert_transaction_with_line_item(party, date, line_item) do
    receive do
      {:transaction, ^party, ^date, ^line_item} -> true
    after
      @timeout ->
        flunk """
        Transaction did not occur with '#{party}' on #{date} with the line item:

        #{inspect line_item}
        """
    end
  end

  @spec refute_transaction(String.t, Date.t) :: true | no_return
  def refute_transaction(from, date) do
    receive do
      {:transaction, ^from, ^date, _} ->
        flunk "Unexepcted transaction occurred."
    after
      @timeout -> true
    end
  end
end
