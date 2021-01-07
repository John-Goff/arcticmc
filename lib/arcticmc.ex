defmodule Arcticmc do
  @moduledoc """
  Starter application using the Scenic framework.
  """

  alias Arcticmc.Config

  def start(_type, _args) do
    Config.initialize_config()

    children = [
      {Ratatouille.Runtime.Supervisor,
       runtime: [app: Arcticmc.CLI, quit_events: [key: Ratatouille.Constants.key(:ctrl_d)]]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Arcticmc.Supervisor)
  end
end
