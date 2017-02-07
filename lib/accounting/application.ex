defmodule Accounting.Application do
  use Application

  @moduledoc false

  @adapter Application.get_env(:accounting, :adapter, Accounting.TestAdapter)

  ## Callbacks

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Supervisor.start_link [worker(@adapter, [])],
      strategy: :one_for_one,
      name: Accounting.Supervisor
  end
end
