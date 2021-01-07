defmodule Arcticmc.MixProject do
  use Mix.Project

  def project do
    [
      app: :arcticmc,
      version: "0.1.0",
      elixir: "~> 1.11",
      build_embedded: true,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Arcticmc, []},
      extra_applications: [:crypto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Display
      {:scenic, "~> 0.10"},
      {:scenic_driver_glfw, "~> 0.10", targets: :host},
      {:ratatouille, "~> 0.5.0"},

      # Tools
      {:logger_file_backend, "~> 0.0.11"},

      # Parsing config/metadata
      {:sweet_xml, "~> 0.6.0"},
      {:yaml_elixir, "~> 2.5.0"}
    ]
  end
end
