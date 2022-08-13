defmodule ReasonTest do
  use ExUnit.Case

  doctest Reason
  doctest Reason.Var
  doctest Reason.Subst
  doctest Reason.Goal

  alias Reason.Goal
  import Reason

  # defp appendo(l, s, out) do
  #   fn subst ->
  #     Reason.disj([
  #       Reason.conj([
  #         Goal.identical(l, []),
  #         Goal.identical(s, out)
  #       ]),
  #       Reason.fresh [a, d, res] do
  #         Goal.identical([a | d], l)
  #         Goal.identical([a | res], out)
  #         appendo(d, s, res)
  #       end
  #     ]).(subst)
  #   end
  # end

  defrel appendo(l, s, out) do
    disj([
      conj([
        Goal.identical(l, []),
        Goal.identical(s, out)
      ]),
      fresh [a, d, res] do
        Goal.identical([a | d], l)
        Goal.identical([a | res], out)
        appendo(d, s, res)
      end
    ])
  end

  test "appendo" do
    answer =
      run false, q do
        fresh [x, y] do
          appendo(x, y, [:a, :b, :c])
          Goal.identical(q, [x, y])
        end
      end

    assert answer == [
             [[], [:a, :b, :c]],
             [[:a], [:b, :c]],
             [[:a, :b], [:c]],
             [[:a, :b, :c], []]
           ]
  end
end
