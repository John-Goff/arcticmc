defmodule Arcticmc.CLI do
  @behaviour Ratatouille.App

  import Ratatouille.View
  import Ratatouille.Constants, only: [key: 1]
  alias Arcticmc.Config
  alias Arcticmc.Paths
  alias Arcticmc.Player
  alias Ratatouille.Window

  @up key(:arrow_up)
  @down key(:arrow_down)
  @left key(:arrow_left)
  @right key(:arrow_right)
  @enter key(:enter)

  defstruct [:directory, :entries, :cursor_pos, :lines, :cols, :scroll_pos, :playback_overlay]

  def run(opts \\ []), do: Ratatouille.run(__MODULE__, opts)

  def init(_context) do
    {lines, cols} = _terminal_size()
    entries = Paths.list_items_to_print(nil)

    %__MODULE__{
      cursor_pos: 0,
      scroll_pos: 0,
      playback_overlay: false,
      lines: lines,
      cols: cols,
      entries: entries
    }
  end

  def update(%__MODULE__{playback_overlay: playback} = state, msg) do
    case msg do
      {:event, %{key: key}} when key in [@up, @down] and not playback ->
        _move_cursor(state, key)

      {:event, %{key: key}} when key in [@left, @down] and playback ->
        playback = Config.get(:playback_speed)
        Config.set(:playback_speed, (trunc(playback * 10) - 1) / 10)
        state

      {:event, %{key: key}} when key in [@right, @up] and playback ->
        playback = Config.get(:playback_speed)
        Config.set(:playback_speed, (trunc(playback * 10) + 1) / 10)
        state

      {:event, %{key: @enter}} when not playback ->
        _select_entry(state)

      {:event, %{ch: ?n}} when not playback ->
        _next_directory_or_file(state)

      {:event, %{ch: ?p}} ->
        %__MODULE__{state | playback_overlay: !state.playback_overlay}

      _ ->
        state
    end
  end

  def render(state) do
    top_bar = bar(do: label(content: "Please select a directory or file"))
    bottom_bar = bar(do: label(content: "(q)uit, (n)ext file, (p)layback speed: #{Config.get(:playback_speed)}"))

    view(top_bar: top_bar, bottom_bar: bottom_bar) do
      _print_current_directory(state)

      if state.playback_overlay do
        overlay(padding: 15) do
          panel(title: "Change playback speed", height: :fill) do
            label(content: to_string(Config.get(:playback_speed)))
          end
        end
      end
    end
  end

  defp _print_current_directory(%__MODULE__{directory: nil, entries: entries, cursor_pos: pos}) do
    [label(content: "Home"), _print_paths(entries, offset: 1, cursor: pos)]
  end

  defp _print_current_directory(%__MODULE__{
         directory: directory,
         entries: entries,
         scroll_pos: scroll,
         cursor_pos: pos
       }) do
    [
      label(content: "Current Directory: #{Paths.file_name_without_extension(directory)}"),
      _print_paths(entries, cursor: pos, scroll: scroll)
    ]
  end

  defp _print_paths(paths, opts) do
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
      if pos >= state.lines - 5 + state.scroll_pos do
        state.scroll_pos + 1
      else
        state.scroll_pos
      end

    %__MODULE__{state | cursor_pos: pos + 1, scroll_pos: scroll}
  end

  # When at the bottom, do not move cursor
  defp _move_cursor(%__MODULE__{} = state, @down) do
    state
  end

  defp _next_directory_or_file(%__MODULE__{entries: entries} = state) do
    next = Enum.find(tl(entries), fn s -> not Player.is_played?(s) end)

    next
    |> _play_or_select()
    |> (fn dir -> %__MODULE__{state | directory: dir, entries: Paths.list_items_to_print(dir)} end).()
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

  defp _play_or_select(nil, _base), do: nil

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
