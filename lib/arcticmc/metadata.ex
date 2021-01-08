defmodule Arcticmc.Metadata do
  @moduledoc """
  Handles fetching and parsing metadata from nfo files.
  """

  require Logger

  def get_metadata(path) do
    path =
      cond do
        File.dir?(path) ->
          Path.join([path, "tvshow.nfo"])

        String.contains?(Path.basename(path), ".") ->
          "#{Path.rootname(path)}.nfo"

        true ->
          path
      end

    Logger.debug("Reading metadata from #{path}")
    File.read(path)
  end
end
