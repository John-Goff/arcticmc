alias Arcticmc.Config
alias Arcticmc.Paths
alias Arcticmc.Player

defmodule CLI do
  @help_text "Could not understand input. Please type a number corresponding to your selection"

  def main_loop(directory) do
    IO.puts("Please select a directory or file")
    print_current_directory(directory)
    IO.puts("q to quit, n to play next unplayed file")
    process_input(directory, IO.gets("> "))
  end

  defp print_current_directory(nil) do
    IO.puts("Home")
    print_paths(Paths.list_items_to_print(nil), offset: 1)
  end

  defp print_current_directory(directory) do
    IO.puts("Current Directory: #{Paths.file_name_without_extension(directory)}")
    print_paths(Paths.list_items_to_print(directory))
  end

  defp print_paths(paths, opts \\ []) do
    offset = Keyword.get(opts, :offset, 0)

    IO.puts("Selection\tDirectory\tPlayed\tItem")

    paths
    |> Enum.with_index()
    |> Enum.each(fn {path, idx} ->
      item = Paths.file_name_without_extension(path)

      IO.puts(
        "#{if Player.is_played?(path), do: IO.ANSI.green()}#{idx + offset})\t\t#{
          if File.dir?(path), do: "*"
        }\t\t#{if Player.is_played?(path), do: "*"}\t#{item}#{IO.ANSI.reset()}"
      )
    end)
  end

  defp process_input(_directory, "q\n"), do: :ok

  defp process_input(nil, input) do
    directory =
      case Integer.parse(input) do
        :error ->
          IO.puts(@help_text)
          nil

        {number, _rem} ->
          paths = Paths.list_items_to_print(nil)

          Enum.at(paths, number - 1)
      end

    main_loop(directory)
  end

  defp process_input(directory, "n\n") do
    next =
      Enum.find(tl(Paths.list_items_to_print(directory)), fn s -> not Player.is_played?(s) end)

    next
    |> play_or_select()
    |> main_loop()
  end

  defp process_input(directory, input) do
    directory =
      case Integer.parse(input) do
        :error ->
          IO.puts(@help_text)
          directory

        {0, _rem} ->
          Paths.parent_directory(directory)

        {number, _rem} ->
          paths = Paths.list_items_to_print(directory)
          play_or_select(Enum.at(paths, number))
      end

    main_loop(directory)
  end

  defp play_or_select(selection) do
    if File.dir?(selection) do
      selection
    else
      Player.play_file(selection)
    end
  end
end

Config.initialize_config()
CLI.main_loop(nil)
