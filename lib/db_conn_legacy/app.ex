defmodule DBConnLegacy.App do
  @moduledoc false
  use Application

  import Supervisor.Spec

  def start(_, _) do
    children = [
      supervisor(DBConnLegacy.Task, []),
      supervisor(DBConnLegacy.Sojourn.Supervisor, []),
      supervisor(DBConnLegacy.Ownership.PoolSupervisor, [])
   ]
    Supervisor.start_link(children, [strategy: :one_for_one, name: __MODULE__])
  end
end
