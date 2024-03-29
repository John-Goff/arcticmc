# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

# Configure the main viewport for the Scenic application
config :arcticmc, :viewport, %{
  name: :main_viewport,
  size: {700, 600},
  default_scene: {Arcticmc.Scene.Home, nil},
  drivers: [
    %{
      module: Scenic.Driver.Glfw,
      name: :glfw,
      opts: [resizeable: true, title: "arcticmc"]
    }
  ]
}

config :logger, backends: [{LoggerFileBackend, :debug_log}]

config :logger, :debug_log,
  path: "debug.log",
  level: :debug

config :logger, :console, level: :error

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "prod.exs"
