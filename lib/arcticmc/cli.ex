defmodule Arcticmc.CLI do
  @behaviour Ratatouille.App

  import Ratatouille.View
  import Ratatouille.Constants, only: [key: 1]
  alias Arcticmc.Config
  alias Arcticmc.Paths
  alias Arcticmc.Player
  alias Ratatouille.Runtime.Command
  alias Ratatouille.Window

  @up key(:arrow_up)
  @down key(:arrow_down)
  @left key(:arrow_left)
  @right key(:arrow_right)
  @enter key(:enter)
  @esc key(:esc)
  @spacebar key(:space)
  @home key(:home)
  @endkey key(:end)
  @delete_keys [
    key(:delete),
    key(:backspace),
    key(:backspace2)
  ]

  # How many lines are taken up by UI elements
  @reserved_lines 5

  defstruct [
    :directory,
    :entries,
    :cursor_pos,
    :lines,
    :cols,
    :scroll_pos,
    :playback_overlay,
    :selection,
    :rename,
    :currently_playing
  ]

  def run(opts \\ []),
    do: Ratatouille.run(__MODULE__, [{:quit_events, [key: key(:ctrl_d)]} | opts])

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

  def update(%__MODULE__{playback_overlay: playback, rename: rename} = state, msg) do
    cond do
      playback -> _update_playback(state, msg)
      not is_nil(rename) -> _update_rename(state, msg)
      true -> _update(state, msg)
    end
  end

  defp _update_playback(state, msg) do
    case msg do
      {:event, %{key: key}} when key in [@left, @down] ->
        playback = Config.get(:playback_speed)
        Config.set(:playback_speed, (trunc(playback * 10) - 1) / 10)
        state

      {:event, %{key: key}} when key in [@right, @up] ->
        playback = Config.get(:playback_speed)
        Config.set(:playback_speed, (trunc(playback * 10) + 1) / 10)
        state

      {:event, %{ch: ch, key: key}} when ch == ?p or key in [@esc, @enter] ->
        %__MODULE__{state | playback_overlay: false}

      _ ->
        state
    end
  end

  defp _update_rename(%__MODULE__{rename: rename} = state, msg) do
    case msg do
      {:event, %{key: @left}} when rename.cursor > 0 ->
        %__MODULE__{state | rename: %{rename | cursor: rename.cursor - 1}}

      {:event, %{key: @right}} ->
        if String.length(rename.name) > rename.cursor do
          %__MODULE__{state | rename: %{rename | cursor: rename.cursor + 1}}
        else
          state
        end

      {:event, %{key: key}} when key in @delete_keys and rename.cursor != 0 ->
        parts = String.graphemes(rename.name)
        new_parts = Enum.take(parts, rename.cursor - 1) ++ Enum.drop(parts, rename.cursor)

        %__MODULE__{
          state
          | rename: %{rename | name: Enum.join(new_parts), cursor: rename.cursor - 1}
        }

      {:event, %{key: @spacebar}} ->
        parts = String.graphemes(rename.name)
        new_parts = Enum.take(parts, rename.cursor) ++ [" "] ++ Enum.drop(parts, rename.cursor)

        %__MODULE__{
          state
          | rename: %{rename | name: Enum.join(new_parts), cursor: rename.cursor + 1}
        }

      {:event, %{key: @enter}} ->
        _rename_entry_to(state)

      {:event, %{key: @home}} ->
        %__MODULE__{state | rename: %{rename | cursor: 0}}

      {:event, %{key: @endkey}} ->
        %__MODULE__{state | rename: %{rename | cursor: String.length(rename.name)}}

      {:event, %{ch: ch}} when ch > 0 ->
        parts = String.graphemes(rename.name)

        new_parts =
          Enum.take(parts, rename.cursor) ++ [<<ch::utf8>>] ++ Enum.drop(parts, rename.cursor)

        %__MODULE__{
          state
          | rename: %{rename | name: Enum.join(new_parts), cursor: rename.cursor + 1}
        }

      {:event, %{key: @esc}} ->
        %__MODULE__{state | rename: nil}

      _ ->
        state
    end
  end

  defp _update(%__MODULE__{} = state, msg) do
    case msg do
      {:event, %{key: key}} when key in [@up, @down] ->
        _move_cursor(state, key)

      {:event, %{key: @enter}} ->
        _select_entry(state)

      {:event, %{key: @esc}} ->
        _handle_esc(state)

      {:event, %{key: key}}
      when key in @delete_keys and is_binary(state.selection) and state.selection != "" ->
        _delete_selection(state)

      {:event, %{ch: num}} when num in ?0..?9 ->
        _enter_selection(state, num)

      {:event, %{ch: ?n}} ->
        _next_directory_or_file(state)

      {:event, %{ch: ?m}} ->
        _toggle_played(state)

      {:event, %{ch: ?p}} ->
        %__MODULE__{state | playback_overlay: true}

      {:event, %{ch: ?r}} ->
        _rename_entry(state)

      {:currently_playing, directory} ->
        %__MODULE__{state | currently_playing: nil}
        |> _new_directory(directory, reset_cursor: false)

      _ ->
        state
    end
  end

  def render(%__MODULE__{} = state) do
    top_bar = bar(do: label(content: "Please select a directory or file"))

    bbcontent =
      cond do
        not is_nil(state.selection) ->
          "> #{state.selection}"

        not is_nil(state.currently_playing) ->
          "Now Playing: #{Paths.file_name_without_extension(state.currently_playing)}"

        true ->
          "(n)ext file, (p)layback speed: #{Config.get(:playback_speed)}, (m)ark played/unplayed, (r)ename, ctrl-d to quit"
      end

    bottom_bar = bar(do: label(content: bbcontent))

    view(top_bar: top_bar, bottom_bar: bottom_bar) do
      _print_current_directory(state)

      if state.playback_overlay do
        overlay(padding: 15) do
          panel(title: "Change playback speed", height: :fill) do
            label(content: "Current speed: #{Config.get(:playback_speed)}")
          end
        end
      end

      if not is_nil(state.rename) do
        parts = state.rename.name |> String.graphemes()

        name =
          parts
          |> Enum.take(state.rename.cursor)
          |> Kernel.++(["▌"])
          |> Kernel.++(Enum.drop(parts, state.rename.cursor))
          |> Enum.join()

        overlay(padding: 15) do
          panel(title: "Rename File or Directory", height: :fill) do
            label(content: name)
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
            File.dir?(path) -> :blue
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
      if pos >= state.lines - @reserved_lines + state.scroll_pos do
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
    entries
    |> Enum.with_index()
    |> tl()
    |> Enum.find(fn {s, _i} -> not Player.is_played?(s) end)
    |> (fn {dir, idx} ->
      state
      |> _change_cursor_pos(idx)
      |> _play_or_select(dir, state.directory)
    end).()
  end

  # change mode
  # defp _select_entry(%__MODULE__{directory: nil, cursor_pos: pos} = state) do
  #   directory = Enum.at(Paths.list_items_to_print(nil), pos)
  #   %__MODULE__{state | directory: directory}
  # end

  # Select item directly
  defp _select_entry(%__MODULE__{selection: select} = state) when is_binary(select) do
    {select, _rem} = Integer.parse(select)
    _select_entry_at(state, select)
  end

  # Select item under cursor
  defp _select_entry(%__MODULE__{cursor_pos: pos} = state) do
    _select_entry_at(state, pos)
  end

  defp _select_entry_at(%__MODULE__{directory: base, entries: entries} = state, pos) do
    directory = Enum.at(entries, pos)
    _play_or_select(state, directory, base)
  end

  defp _new_directory(state, directory, opts \\ []) do
    reset = Keyword.get(opts, :reset_cursor, true)
    entries = Paths.list_items_to_print(directory)

    %__MODULE__{
      state
      | directory: directory,
        entries: entries,
        cursor_pos: if(reset, do: 0, else: state.cursor_pos),
        scroll_pos: if(reset, do: 0, else: state.scroll_pos),
        selection: nil
    }
  end

  defp _play_or_select(state, "..", nil), do: _new_directory(state, nil)

  defp _play_or_select(state, "..", base) do
    # Return to home directory if at top level
    if base in Paths.list_items_to_print(nil) do
      _new_directory(state, nil)
    else
      _new_directory(state, Paths.parent_directory(base))
    end
  end

  defp _play_or_select(state, nil, _base), do: _new_directory(state, nil)

  defp _play_or_select(state, selection, _base) do
    if File.dir?(selection) do
      _new_directory(state, selection)
    else
      new_state = %__MODULE__{state | currently_playing: selection}
      {new_state, Command.new(fn -> Player.play_file(selection) end, :currently_playing)}
    end
  end

  defp _handle_esc(%__MODULE__{directory: base} = state) do
    _play_or_select(state, "..", base)
  end

  defp _rename_entry(%__MODULE__{cursor_pos: pos, entries: entries} = state) do
    directory = Enum.at(entries, pos)
    name = List.last(Path.split(directory))
    cursor = String.length(name)
    %__MODULE__{state | rename: %{name: name, cursor: cursor}}
  end

  defp _rename_entry_to(
         %__MODULE__{
           directory: directory,
           cursor_pos: pos,
           entries: entries,
           rename: %{name: name}
         } = state
       ) do
    selected_directory = Enum.at(entries, pos)
    File.rename!(selected_directory, Path.join(directory, name))

    %__MODULE__{state | rename: nil}
    |> _new_directory(directory)
  end

  defp _toggle_played(%__MODULE__{directory: base, cursor_pos: pos, entries: entries} = state) do
    directory = Enum.at(entries, pos)

    if Player.is_played?(directory) do
      File.rename!(directory, String.replace(directory, Player.played(), ""))
    else
      Player.mark_played(directory)
    end

    entries = Paths.list_items_to_print(base)

    %__MODULE__{state | entries: entries}
  end

  defp _enter_selection(state, num) do
    new_sel = "#{state.selection}#{<<num>>}"
    _change_selection(state, new_sel)
  end

  defp _delete_selection(%__MODULE__{selection: selection} = state) do
    if String.length(selection) == 1 do
      %__MODULE__{state | selection: nil}
    else
      new_sel =
        selection |> String.graphemes() |> Enum.reverse() |> tl() |> Enum.reverse() |> Enum.join()

      _change_selection(state, new_sel)
    end
  end

  defp _change_selection(state, new_sel) do
    %__MODULE__{state | selection: new_sel}
    |> _change_cursor_pos(String.to_integer(new_sel))
  end

  defp _change_cursor_pos(state, pos) do
    scroll =
      cond do
        state.scroll_pos > pos ->
          pos

        pos > state.scroll_pos + state.lines - @reserved_lines ->
          pos - state.lines + @reserved_lines

        true ->
          state.scroll_pos
      end

    %__MODULE__{state | cursor_pos: pos, scroll_pos: scroll}
  end

  defp _terminal_size do
    {:ok, lines} = Window.fetch(:height)
    {:ok, cols} = Window.fetch(:width)
    {lines, cols}
  end
end
