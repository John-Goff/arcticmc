defmodule Arcticmc.Player do
  @moduledoc """
  Handles playing and renaming files.
  """

  require Logger
  alias Arcticmc.Config
  alias Arcticmc.Paths

  @played "✓"

  def played, do: @played

  def play_file(path) do
    _open_player(path)

    path =
      if is_played?(path) do
        path
      else
        mark_played(path)
      end

    parent_dir = Path.dirname(path)

    if Enum.all?(tl(Paths.list_items_to_print(parent_dir)), &is_played?/1) do
      mark_played(parent_dir)
    else
      parent_dir
    end
  end

  defp _open_player(path) do
    Logger.debug("Playing file #{path}")
    options = ["--rate", "#{Config.get(:playback_speed)}", path]

    options =
      if Config.get(:fullscreen) do
        ["--fullscreen" | options]
      else
        options
      end

    System.cmd("vlc", options, stderr_to_stdout: true)
  end

  def is_played?(path) do
    String.contains?(Path.basename(path), @played)
  end

  @doc """
  Marks a file as played.

  Adds the #{@played} character to the filename, and returns the new path of the file.
  """
  def mark_played(path) do
    Logger.debug(fn -> "Marking #{Path.basename(path)} as played" end)
    new_path = add_played_to_path(path)
    File.rename(path, new_path)
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
    Logger.debug(fn -> "path: #{path}" end)
    Logger.debug(fn -> "new_path: #{new_path}" end)
    File.rename(path, new_path)
    new_path
  end

  def add_played_to_path(path) do
    if File.dir?(path) or not String.contains?(path, ".") do
      path <> @played
    else
      [working | rest_path] =
        path
        |> Path.split()
        |> Enum.reverse()

      parts = String.split(working, ".")

      [ext | rest] = Enum.reverse(parts)
      new_filename = Enum.join(Enum.reverse(rest), ".") <> @played
      new = "#{new_filename}.#{ext}"
      Path.join(Enum.reverse([new | rest_path]))
    end
  end
end
