defmodule Accounting.Application do
  use Application

  alias Accounting.TestAdapter

  @moduledoc false

  ## Callbacks

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Supervisor.start_link [worker(adapter(), [])],
      strategy: :one_for_one,
      name: Accounting.Supervisor
  end

  defp adapter, do: Application.get_env(:accounting, :adapter, TestAdapter)
end
