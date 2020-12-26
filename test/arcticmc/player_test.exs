defmodule Arcticmc.PlayerTest do
  use ExUnit.Case, async: true

  alias Arcticmc.Player, as: Subject

  @played "✓"

  describe "is_played?/1" do
    test "checks for the #{@played} character in a string" do
      assert Subject.is_played?(@played)
      assert Subject.is_played?("/home/user/Movies/filename#{@played}.mp4")
      refute Subject.is_played?("")
      refute Subject.is_played?("/home/user/Movies/filename.mp4")
    end
  end

  describe "add_played_to_path/1" do
    test "adds a #{@played} character to the filename" do
      assert Subject.add_played_to_path("filename") =~ @played
      assert Subject.add_played_to_path("filename.mp4") =~ @played
      assert Subject.add_played_to_path("/home/user/Movies/filename.mp4") =~ @played
    end

    test "#{@played} character should be before extension" do
      assert "mp4" == "filename.mp4" |> Subject.add_played_to_path() |> String.split("#{@played}.") |> List.last()
    end
  end
end
