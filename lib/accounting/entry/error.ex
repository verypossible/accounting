defmodule Accounting.Entry.Error do
  @moduledoc """
  A journal entry error.
  """

  alias Accounting.Entry

  @type t :: %__MODULE__{entry: Entry.t, errors: [String.t, ...]}

  @enforce_keys [:entry, :errors]
  defstruct [:entry, :errors]
end
