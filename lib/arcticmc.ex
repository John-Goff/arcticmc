defmodule Arcticmc do
  @moduledoc """
  Starter application using the Scenic framework.
  """

  alias Arcticmc.Paths

  def start(_type, _args) do
    # load the viewport configuration from config
    main_viewport_config = Application.get_env(:arcticmc, :viewport)

    initialize_config()

    # start the application with the viewport
    children = [
      {Scenic, viewports: [main_viewport_config]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def initialize_config() do
    _get_config_contents()
    |> Enum.each(fn {key, value} ->
      Paths.set(key, value)
    end)
  end

  defp _get_config_contents() do
    # load paths into persistent term for later use
    path = Paths.config_path()
    File.mkdir_p!(path)
    config_file = Path.join([path, "config.yaml"])

    with {:ok, config_data} <- YamlElixir.read_from_file(config_file) do
      config_data
    else
      {:error, %YamlElixir.FileNotFoundError{}} ->
        File.cp(Path.join([:code.priv_dir(:arcticmc), "config_sample.yaml"]), config_file)
        YamlElixir.read_from_file!(config_file)
    end
  end
end
