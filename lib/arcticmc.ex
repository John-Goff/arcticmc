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

  defp initialize_config() do
    get_config_contents()
    |> String.split("\n")
    |> Enum.each(fn line ->
      line_data = String.split(line, ": ")
      if match?([_, _], line_data) do
        [key, value] = line_data
        Paths.set(key, value)
      end
    end)
  end

  defp get_config_contents() do
    # load paths into persistent term for later use
    path = Paths.config_path()
    File.mkdir_p!(path)
    config_file = Path.join([path, "config"])

    with {:ok, config_data} <- File.read(config_file) do
      config_data
    else
      {:error, :enoent} ->
        File.touch(config_file)
        ""
    end
  end
end
