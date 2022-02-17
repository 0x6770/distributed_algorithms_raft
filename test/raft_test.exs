defmodule RaftTest do
  use ExUnit.Case
  doctest Raft

  def add1(num) do
    num + 1
  end

  test "test add1" do
    assert add1(4) == 5
  end
end
