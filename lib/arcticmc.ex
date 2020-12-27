defmodule Arcticmc do
  @moduledoc """
  Starter application using the Scenic framework.
  """

  alias Arcticmc.Config

  def start(_type, _args) do
    # load the viewport configuration from config
    main_viewport_config = Application.get_env(:arcticmc, :viewport)

    Config.initialize_config()

    # start the application with the viewport
    children = [
      {Scenic, viewports: [main_viewport_config]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
