defmodule Accounting.Entry do
  @moduledoc """
  A journal entry struct.
  """

  alias Accounting.LineItem

  @type t :: %__MODULE__{
    date: Date.t,
    line_items: [LineItem.t, ...],
    party: String.t,
    total: integer,
  }

  @enforce_keys [:date, :line_items, :party, :total]
  defstruct [:date, :line_items, :party, :total]

  @spec new(String.t, Date.t, [LineItem.t, ...]) :: t
  def new(<<_::binary>> = party, %Date{} = date, [_|_] = line_items) do
    total = List.foldl(line_items, 0, & &1.amount + &2)
    %__MODULE__{
      date: date,
      line_items: line_items,
      party: party,
      total: total,
    }
  end
end
