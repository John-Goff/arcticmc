defmodule Arcticmc.Paths do
  @moduledoc """
  Module for accessing the currently defined media paths
  """

  alias Arcticmc.Player

  @allowed_keys [:tv, :movies]
  @string_allowed_keys Enum.map(@allowed_keys, &Atom.to_string/1)

  def allowed_paths, do: @allowed_keys

  def get(key) when key in @allowed_keys, do: :persistent_term.get({__MODULE__, key})

  def set(key, path) when key in @string_allowed_keys, do: set(String.to_existing_atom(key), path)
  def set(key, path) when key in @allowed_keys, do: :persistent_term.put({__MODULE__, key}, path)

  def config_path() do
    case {System.get_env("ARCTICMC_HOME"), System.get_env("XDG_CONFIG_HOME")} do
      {directory, _} when is_binary(directory) -> directory
      {nil, directory} when is_binary(directory) -> :filename.basedir(:user_config, "arcticmc")
      {nil, nil} -> Path.expand("~/.arcticmc")
    end 
  end

  def file_name_without_extension(path) do
    if File.dir?(path) do
      last_elem_without_checkmark(path)
    else
      path
      |> last_elem_without_checkmark()
      |> String.split(".")
      |> Enum.reverse()
      |> tl()
      |> Enum.reverse()
      |> Enum.join(".")
    end
  end

  defp last_elem_without_checkmark(path) do
    path
    |> Path.split()
    |> List.last()
    |> String.replace(Player.played(), "")
  end

  def parent_directory(directory) do
    directory
    |> Path.split()
    |> Enum.reverse()
    |> case do
      [] -> []
      list -> tl(list)
    end
    |> Enum.reverse()
    |> Path.join()
  end
end
