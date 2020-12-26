defmodule Arcticmc.Player do
  @moduledoc """
  Handles playing and renaming files.
  """

  @played "✓"

  def play_file(path) do
    unless is_played?(path) do
      mark_played(path)
    end

    System.cmd("vlc", [path])
  end

  def is_played?(path) do
    String.contains?(path, @played)
  end

  def mark_played(path) do
    File.rename(path, add_played_to_path(path))
  end

  def add_played_to_path(path) do
    parts = String.split(path, ".")
    [ext | rest] = Enum.reverse(parts)
    Enum.join(Enum.reverse([ext, @played | rest]), ".")
  end
end
