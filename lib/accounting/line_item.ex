defmodule Accounting.LineItem do
  @moduledoc """
  A line item struct.
  """

  @type t :: %__MODULE__{}

  defstruct [:account_number, :amount, {:category, :other}, :description]
end
