alias Arcticmc.Paths
alias Arcticmc.Player

defmodule CLI do
  @help_text "Could not understand input. Please type a number corresponding to your selection"

  def main_loop(directory) do
    IO.puts("Please select a directory or file")
    print_current_directory(directory)
    process_input(directory, IO.gets("> "))
  end

  defp print_current_directory(nil) do
    Paths.allowed_paths()
    |> Enum.map(fn type ->
      try do
        Paths.get(type)
      rescue
        _ -> ""
      end
    end)
    |> Enum.reject(fn s -> s == "" end)
    |> print_paths(offset: 1)
  end

  defp print_current_directory(directory) do
    directory
    |> File.ls!()
    |> Enum.map(fn item -> Path.join([directory, item]) end)
    |> (fn paths -> [".." | paths] end).()
    |> print_paths()
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
          paths =
            Paths.allowed_paths()
            |> Enum.map(fn type ->
              try do
                Paths.get(type)
              rescue
                _ -> ""
              end
            end)
            |> Enum.reject(fn s -> s == "" end)

          Enum.at(paths, number - 1)
      end

    main_loop(directory)
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
          paths = File.ls!(directory)
          selection = Enum.at(paths, number - 1)
          new_dir = Path.join([directory, selection])

          if File.dir?(new_dir) do
            new_dir
          else
            Player.play_file(new_dir)
          end
      end

    main_loop(directory)
  end
end

Arcticmc.initialize_config()
CLI.main_loop(nil)
