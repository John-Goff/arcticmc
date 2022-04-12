defmodule Arcticmc.Player do
  @moduledoc """
  Handles playing and renaming files.
  """

  require Logger
  alias Arcticmc.Config
  alias Arcticmc.Metadata
  alias Arcticmc.Paths

  @played "✓"

  @doc """
  Character which marks an item as played.
  """
  @spec played() :: String.t()
  def played, do: @played

  @doc """
  Plays the selected file and marks it as played.
  """
  def play_file(:movies, path) do
    path |> _play_file() |> Path.dirname()
  end

  def play_file(_, path) do
    _play_file(path)
  end

  defp _play_file(path) do
    _open_player(path)

    path = _mark_played_if_not(path)

    parent_dir = Path.dirname(path)

    if Enum.all?(tl(Paths.list_items_to_print(parent_dir)), &is_played?/1) do
      _mark_played_if_not(parent_dir)
    else
      parent_dir
    end
  end

  defp _mark_played_if_not(path) do
    if is_played?(path) do
      path
    else
      mark_played(path)
    end
  end

  defp _open_player(path) do
    Logger.debug("Playing file #{path}")
    options = ["--speed=#{Config.get(:playback_speed)}", path]

    options =
      if Config.get(:fullscreen) do
        ["--fullscreen" | options]
      else
        options
      end

    System.cmd("mpv", options, stderr_to_stdout: true)
  end

  def is_played?({_mode, path}), do: is_played?(path)
  def is_played?(path), do: String.contains?(Path.basename(path), @played)

  @doc """
  Marks a file as played.

  Adds the #{@played} character to the filename, and returns the new path of the file.
  """
  @spec mark_played(path :: String.t()) :: String.t()
  def mark_played(path) do
    Logger.debug(fn -> "Marking #{Path.basename(path)} as played" end)
    new_path = add_played_to_path(path)
    File.rename(path, new_path)

    metadata_path = Metadata.metadata_path(path)

    if File.exists?(metadata_path),
      do: File.rename(metadata_path, add_played_to_path(metadata_path))

    subtitle_path = "#{Path.rootname(path)}.eng.srt"

    if File.exists?(subtitle_path),
      do: File.rename(subtitle_path, add_played_to_path(subtitle_path, ".eng.srt"))

    thumb_path = "#{Path.rootname(path)}-thumb.jpg"

    if File.exists?(thumb_path),
      do: File.rename(thumb_path, add_played_to_path(thumb_path, "-thumb.jpg"))

    new_path
  end

  @doc """
  Marks a file as unplayed.

  Removes the #{@played} character from the filename.
  """
  def mark_unplayed(path) do
    Logger.debug(fn -> "Marking #{Path.basename(path)} as unplayed" end)
    filename = path |> Path.basename() |> String.replace(@played, "")
    new_path = Path.join([Path.dirname(path), filename])
    metadata_path = Metadata.metadata_path(path)

    if File.exists?(metadata_path) do
      filename = metadata_path |> Path.basename() |> String.replace(@played, "")
      File.rename(metadata_path, Path.join([Path.dirname(metadata_path), filename]))
    end

    subtitle_path = "#{Path.rootname(path)}.eng.srt"

    if File.exists?(subtitle_path) do
      filename = subtitle_path |> Path.basename(".eng.srt") |> String.replace(@played, "")
      File.rename(subtitle_path, Path.join([Path.dirname(subtitle_path), filename]))
    end

    thumb_path = "#{Path.rootname(path)}-thumb.jpg"

    if File.exists?(thumb_path) do
      filename = thumb_path |> Path.basename("-thumb.jpg") |> String.replace(@played, "")
      File.rename(thumb_path, Path.join([Path.dirname(thumb_path), filename]))
    end

    File.rename(path, new_path)
    new_path
  end

  @doc """
  Adds the #{@played} character to a file or directory.

  If the given path is a directory, or it does not contain an extension, then the
  #{@played} character is added to the end of the path. Otherwise, it is added at
  the end of the base name and before the extension.

  ## Examples

      iex> Subject.add_played_to_path("test")
      "test#{@played}"

      iex> Subject.add_played_to_path("test.mp4")
      "test#{@played}.mp4"
  """
  def add_played_to_path(path), do: add_played_to_path(path, Path.extname(path))

  @doc """
  Adds the #{@played} character to a file or directory with a specific extension.

  If the given path is a directory, or it does not contain an extension, then the
  #{@played} character is added to the end of the path. Otherwise, it is added at
  the end of the base name and before the extension.

  ## Examples

      iex> Subject.add_played_to_path("test", "")
      "test#{@played}"

      iex> Subject.add_played_to_path("test.eng.srt", ".eng.srt")
      "test#{@played}.eng.srt"
  """
  def add_played_to_path(path, extension) do
    if File.dir?(path) or not String.contains?(path, ".") do
      path <> @played
    else
      Path.rootname(path, extension) <> @played <> extension
    end
  end
end
