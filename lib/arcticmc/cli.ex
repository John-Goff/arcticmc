defmodule Arcticmc.CLI do
  @behaviour Ratatouille.App

  import Ratatouille.View
  import Ratatouille.Constants, only: [key: 1]
  alias Arcticmc.Paths
  alias Arcticmc.Player
  alias Ratatouille.Window

  @up key(:arrow_up)
  @down key(:arrow_down)
  @enter key(:enter)

  defstruct [:directory, :entries, :cursor_pos, :lines, :cols, :scroll_pos]

  def run(opts \\ []), do: Ratatouille.run(__MODULE__, opts)

  def init(_context) do
    {lines, cols} = _terminal_size()
    entries = Paths.list_items_to_print(nil)
    %__MODULE__{cursor_pos: 0, scroll_pos: 0, lines: lines, cols: cols, entries: entries}
  end

  def update(state, msg) do
    case msg do
      {:event, %{key: key}} when key in [@up, @down] ->
        _move_cursor(state, key)

      {:event, %{key: @enter}} ->
        _select_entry(state)

      _ ->
        state
    end
  end

  def render(state) do
    top_bar = bar(do: label(content: "Please select a directory or file"))
    bottom_bar = bar(do: label(content: "q to quit, n to play next unplayed file"))

    view(top_bar: top_bar, bottom_bar: bottom_bar) do
      print_current_directory(state)
    end
  end

  defp print_current_directory(%__MODULE__{directory: nil, entries: entries, cursor_pos: pos}) do
    [label(content: "Home"), print_paths(entries, offset: 1, cursor: pos)]
  end

  defp print_current_directory(%__MODULE__{
         directory: directory,
         entries: entries,
         scroll_pos: scroll,
         cursor_pos: pos
       }) do
    [
      label(content: "Current Directory: #{Paths.file_name_without_extension(directory)}"),
      print_paths(entries, cursor: pos, scroll: scroll)
    ]
  end

  defp print_paths(paths, opts) do
    offset = Keyword.get(opts, :offset, 0)
    cursor = Keyword.get(opts, :cursor, 0)
    scroll = Keyword.get(opts, :scroll, 0)

    header =
      table_row do
        table_cell(content: "Selection")
        table_cell(content: "Directory")
        table_cell(content: "Played")
        table_cell(content: "Item")
      end

    table_rows =
      paths
      |> Enum.with_index()
      |> Enum.drop(scroll)
      |> Enum.map(fn {path, idx} ->
        item = Paths.file_name_without_extension(path)

        colour =
          cond do
            Player.is_played?(path) -> :green
            File.dir?(path) -> if(idx == cursor, do: :blue, else: :cyan)
            true -> :black
          end

        opts = [color: colour]

        opts =
          if idx == cursor do
            [{:background, :yellow}, {:attributes, [:bold]} | opts]
          else
            opts
          end

        table_row do
          table_cell([{:content, "#{idx + offset})"} | opts])
          table_cell([{:content, if(File.dir?(path), do: "*")} | opts])
          table_cell([{:content, if(Player.is_played?(path), do: "*", else: "")} | opts])
          table_cell([{:content, item} | opts])
        end
      end)

    table([header | table_rows])
  end

  defp _move_cursor(%__MODULE__{cursor_pos: pos} = state, @up) when pos > 0 do
    scroll =
      if state.scroll_pos == pos do
        state.scroll_pos - 1
      else
        state.scroll_pos
      end

    %__MODULE__{state | cursor_pos: pos - 1, scroll_pos: scroll}
  end

  # When at the top, do not move cursor
  defp _move_cursor(%__MODULE__{} = state, @up) do
    state
  end

  defp _move_cursor(%__MODULE__{cursor_pos: pos, entries: entries} = state, @down)
       when pos < length(entries) - 1 do
    scroll =
      if pos >= (state.lines - 5) + state.scroll_pos do
        state.scroll_pos + 1
      else
        state.scroll_pos
      end
    %__MODULE__{state | cursor_pos: pos + 1, scroll_pos: scroll}
  end

  defp _process_input(%__MODULE__{directory: directory} = state, ?n) do
    next =
      Enum.find(tl(Paths.list_items_to_print(directory)), fn s -> not Player.is_played?(s) end)

    next
    |> _play_or_select()
    |> (fn dir -> %__MODULE__{state | directory: dir} end).()
  end

  # change mode
  # defp _select_entry(%__MODULE__{directory: nil, cursor_pos: pos} = state) do
  #   directory = Enum.at(Paths.list_items_to_print(nil), pos)
  #   %__MODULE__{state | directory: directory}
  # end

  # change directory
  defp _select_entry(%__MODULE__{directory: base, entries: entries, cursor_pos: pos} = state) do
    directory = Enum.at(entries, pos)
    directory = _play_or_select(directory, base)
    entries = Paths.list_items_to_print(directory)
    %__MODULE__{state | directory: directory, entries: entries, cursor_pos: 0, scroll_pos: 0}
  end

  defp _play_or_select(selection, base \\ "")

  defp _play_or_select("..", base) do
    Paths.parent_directory(base)
  end

  defp _play_or_select(selection, _base) do
    if File.dir?(selection) do
      selection
    else
      Player.play_file(selection)
    end
  end

  defp _terminal_size do
    {:ok, lines} = Window.fetch(:height)
    {:ok, cols} = Window.fetch(:width)
    {lines, cols}
  end
end
