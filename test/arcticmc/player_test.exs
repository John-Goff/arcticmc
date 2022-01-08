defmodule Arcticmc.PlayerTest do
  use ExUnit.Case, async: true

  alias Arcticmc.Player, as: Subject
  doctest Subject

  @played "✓"

  describe "is_played?/1" do
    test "checks for the #{@played} character in a string" do
      assert Subject.is_played?(@played)
      assert Subject.is_played?("/home/user/Movies/filename#{@played}.mp4")
      refute Subject.is_played?("")
      refute Subject.is_played?("/home/user/Movies/filename.mp4")
    end
  end
end
