defmodule Arcticmc.Metadata do
  @moduledoc """
  Handles fetching and parsing metadata from nfo files.
  """

  alias Arcticmc.Paths

  def get_metadata(path) do
    if File.dir?(path) do
      File.read(Path.join([path, "tvshow.nfo"]))
    else
      filename = Paths.file_name_without_extension(path)

      if String.contains?(filename, ".") do
        parent = Paths.parent_directory(path)

        filename = "#{filename}.nfo"

        File.read(Path.join([parent, filename]))
      else
        File.read(path)
      end
    end
  end
end
