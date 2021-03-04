defmodule Arcticmc.Paths do
  @moduledoc """
  Module for accessing the currently defined media paths
  """

  require Logger
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

  def file_name_without_extension({_mode, path}), do: file_name_without_extension(path)

  def file_name_without_extension(path) do
    if File.dir?(path) do
      last_elem_without_checkmark(path)
    else
      path
      |> last_elem_without_checkmark()
      |> Path.rootname()
    end
  end

  defp last_elem_without_checkmark(path) do
    path
    |> Path.basename()
    |> String.replace(Player.played(), "")
  end

  # Must contain a beginning period, as this is what Path.extname returns
  @video_extensions [".avi", ".mp4", ".mkv", ".m4v", ".flv"]

  @doc """
  Lists items to print for a given directory.

  Will only list other directories or video files.  Video file includes any
  file that has the extension #{
    @video_extensions |> tl() |> Enum.map(fn s -> "`#{s}`" end) |> Enum.join(", ")
  }, or `#{hd(@video_extensions)}`
  """
  def list_items_to_print(nil) do
    allowed_paths()
    |> Enum.map(fn type ->
      try do
        type
        |> get()
        |> (fn str ->
              Logger.debug("Fetched from config: #{str}")
              str
            end).()
        |> Path.expand()
        |> (fn str ->
              Logger.debug("Expanded: #{str}")
              str
            end).()
        |> (fn str -> {type, str} end).()
      rescue
        _ -> ""
      end
    end)
    |> Enum.reject(fn s -> s == "" end)
    |> Enum.sort(fn {_, a}, {_, b} -> a < b end)
  end

  def list_items_to_print(directory) do
    directory
    |> File.ls!()
    |> Enum.reject(fn
      "." <> _str ->
        true

      str ->
        if File.dir?(Path.join([directory, str])),
          do: false,
          else:
            str
            |> Path.extname()
            |> Kernel.in(@video_extensions)
            |> Kernel.not()
    end)
    |> Enum.map(fn item -> Path.join([directory, item]) end)
    |> Enum.sort()
    |> (fn paths -> [".." | paths] end).()
  end

  @doc """
  Gets the filename of the largest video file in the directory.

  This is assumed to be the movie that is stored in this directory. Video file
  includes any file that has the extension #{
    @video_extensions |> tl() |> Enum.map(fn s -> "`#{s}`" end) |> Enum.join(", ")
  }, or `#{hd(@video_extensions)}`
  """
  def video_file(directory) do
    video_files =
      for file <- File.ls!(directory),
          Path.extname(file) in @video_extensions,
          do: {file, File.stat!(Path.join([directory, file])).size}

    with {largest_file, _file_size} <-
           video_files
           |> Enum.sort(fn {_, f1}, {_, f2} -> f1 >= f2 end)
           |> List.first() do
      largest_file
    end
  end
end
