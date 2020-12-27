defmodule Arcticmc.Config do
  @moduledoc """
  Handles configuring the application.

  Uses `:persistent_term` to store config options loaded from the config file. The config file is a
  YAML formatted file, stored in `$XDG_CONFIG_HOME/arcticmc/config.yaml`. This file is responsible
  for storing the config options, and must be loaded at program start. The full list of options is
  as follows:

  `directories`
  Key containing a map, which contains the list of media locations to load. Currently, only `tv` is
  supported as an option for media to load.
  `fullscreen`
  Boolean, defaults to true. Controls whether the VLC instance launches in fullscreen or windowed
  mode.
  `playback_speed`
  Float. Allows you to set the video playback speed. Defaults to `1.0`
  """

  alias Arcticmc.Paths

  @allowed_options [:fullscreen, :playback_speed]
  @string_allowed_options Enum.map(@allowed_options, &Atom.to_string/1)

  def allowed_options, do: @allowed_options

  def get(key) when key in @allowed_options, do: :persistent_term.get({__MODULE__, key})

  def set(key, path) when key in @string_allowed_options,
    do: set(String.to_existing_atom(key), path)

  def set(key, path) when key in @allowed_options,
    do: :persistent_term.put({__MODULE__, key}, path)

  def initialize_config() do
    _get_config_contents()
    |> Enum.each(fn
      {"directories", value} -> Enum.each(value, fn {k, v} -> Paths.set(k, v) end)
      {key, value} -> set(key, value)
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
