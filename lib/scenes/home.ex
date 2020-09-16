defmodule Arcticmc.Scene.Home do
  use Scenic.Scene
  require Logger

  alias Arcticmc.Paths
  alias Scenic.Graph
  alias Scenic.ViewPort

  import Scenic.Primitives
  # import Scenic.Components

  @note """
    This is a very simple starter application.

    If you want a more full-on example, please start from:

    mix scenic.new.example
  """

  @text_size 24

  # ============================================================================
  # setup

  # --------------------------------------------------------
  def init(_, opts) do
    # get the width and height of the viewport. This is to demonstrate creating
    # a transparent full-screen rectangle to catch user input
    {:ok, %ViewPort.Status{size: {width, height}}} = ViewPort.info(opts[:viewport])

    graph =
      Graph.build(font: :roboto, font_size: @text_size)
      |> add_specs_to_graph([
        rect_spec({width, height})
      ])

    send(self(), {:new_path, Paths.get(:tv)})

    {:ok, graph, push: graph}
  end

  def handle_info({:new_path, path}, graph) do
    files = File.ls!(path)

    graph
    |> render_files(files)
    |> push_graph()

    {:noreply, graph}
  end

  def handle_input(event, _context, state) do
    Logger.info("Received event: #{inspect(event)}")
    {:noreply, state}
  end

  defp render_files(graph, files) do
    add_specs_to_graph(graph, Enum.map(Enum.with_index(files), fn {file, idx} ->
      text_spec(file, translate: {10, idx * 20}, text_height: 20)
    end))
  end
end
