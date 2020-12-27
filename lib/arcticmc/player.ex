defmodule Arcticmc.Player do
  @moduledoc """
  Handles playing and renaming files.
  """

  alias Arcticmc.Paths

  @played "✓"

  def played, do: @played

  def play_file(path) do
    path =
      if is_played?(path) do
        path
      else
        mark_played(path)
      end

    parent_dir = Paths.parent_directory(path)

    parent_dir = if IO.inspect(Enum.all?(File.ls!(parent_dir), &is_played?/1)) do
      IO.inspect(mark_played(parent_dir))
    else
      parent_dir
    end

    filename = path |> Path.split() |> List.last()
    new_file = Path.join([parent_dir, filename])

    System.cmd("vlc", [new_file])
    parent_dir
  end

  def is_played?(path) do
    String.contains?(path, @played)
  end

  def mark_played(path) do
    new_path = add_played_to_path(path)
    IO.inspect(File.rename(path, new_path))
    new_path
  end

  def add_played_to_path(path) do
    if File.dir?(path) do
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
