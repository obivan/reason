defmodule Reason.Goal do
  @moduledoc """
  A _goal_ is a function that maps a substitution to an ordered
  sequence of zero or more values - these values are almost
  always substitutions.

  Because the sequence of values may be infinite, we represent it
  not as a list but as a special kind of stream.

  Thus, a goal is a function that expects a substitution and, if it
  returns, produces a stream of substitutions.
  """

  alias Reason.Subst

  @type suspension :: (() -> stream())
  @type stream :: [] | nonempty_improper_list(Subst.t(), stream) | suspension()

  @type t :: (Subst.t() -> stream())

  @doc """
  The goal that always succeeds.

  Examples:

      iex> alias Reason.{Subst, Var, Goal}
      iex> x = Var.new()
      iex> s = Subst.put(Subst.new(), x, :olive)
      iex> g = Goal.succeed()
      iex> assert g.(s) == [%{x => :olive}]

  """
  @spec succeed() :: t()
  def succeed, do: fn s -> [s] end

  @doc """
  The goal that always fail.

  Examples:

      iex> alias Reason.{Subst, Var, Goal}
      iex> x = Var.new()
      iex> s = Subst.put(Subst.new(), x, :olive)
      iex> g = Goal.fail()
      iex> assert g.(s) == []

  """
  @spec fail() :: t()
  def fail, do: fn _ -> [] end

  @doc """
  The identical (≡) goal.
  It returns a goal that succeeds if its arguments unify.

  Examples:

      iex> alias Reason.{Subst, Var, Goal}
      iex> s = Subst.new()
      iex> x = Var.new()
      iex> g = Goal.identical(x, :olive)
      iex> assert g.(s) == [%{x => :olive}]

      iex> alias Reason.{Subst, Var, Goal}
      iex> s = Subst.new()
      iex> g = Goal.identical(false, true)
      iex> assert g.(s) == []

      iex> alias Reason.{Subst, Var, Goal}
      iex> s = Subst.new()
      iex> [x, y, z] = Var.new_many([:x, :y, :z])
      iex> s = Subst.put(s, x, y)
      iex> s = Subst.put(s, y, z)
      iex> s = Subst.put(s, z, :olive)
      iex> g = Goal.identical(x, :olive)
      iex> assert g.(s) == [%{x => y, y => z, z => :olive}]

  """
  @spec identical(term(), term()) :: t()
  def identical(u, v) do
    fn s ->
      case Subst.unify(s, u, v) do
        false -> []
        w -> [w]
      end
    end
  end

  # Appends two streams one to another
  @spec stream_append(stream(), stream()) :: stream()
  defp stream_append([], s2), do: s2

  defp stream_append([h | t], s2), do: [h | stream_append(t, s2)]

  defp stream_append(suspension, s2) when is_function(suspension) do
    fn -> stream_append(s2, suspension.()) end
  end

  @doc """
  The logic disjunction goal. Succeeds when `g1` or `g2` succeeds.

  Examples

      iex> alias Reason.{Subst, Var, Goal}
      iex> s = Subst.new()
      iex> x = Var.new()
      iex> g1 = Goal.identical(x, :olive)
      iex> g2 = Goal.identical(x, :oil)
      iex> g = Goal.disj(g1, g2)
      iex> assert g.(s) == [%{x => :olive}, %{x => :oil}]

  """
  @spec disj(t(), t()) :: t()
  def disj(g1, g2) do
    fn s ->
      stream_append(g1.(s), g2.(s))
    end
  end

  # def nevero() do
  #   fn s ->
  #     fn ->
  #       nevero().(s)
  #     end
  #   end
  # end

  # def alwayso() do
  #   fn s ->
  #     fn ->
  #       disj(succeed(), alwayso()).(s)
  #     end
  #   end
  # end

  # @spec stream_take(stream()) :: [Subst.t()]
  # def stream_take(s), do: stream_take(s, false)

  @spec stream_take(stream(), non_neg_integer() | false) :: [Subst.t()]
  def stream_take(_s, 0), do: []
  def stream_take([], _n), do: []
  def stream_take([h | t], n), do: [h | stream_take(t, n && n - 1)]
  def stream_take(s, n), do: stream_take(s.(), n)

  @spec stream_append_map(stream(), t()) :: stream()
  defp stream_append_map([], _g), do: []

  defp stream_append_map([h | t], g) do
    stream_append(g.(h), stream_append_map(t, g))
  end

  defp stream_append_map(s, g), do: stream_append_map(s.(), g)

  @spec conj(t(), t()) :: t()
  def conj(g1, g2) do
    fn s ->
      stream_append_map(g1.(s), g2)
    end
  end

  # @spec call_fresh(name :: Var.name(), f :: (Var.t() -> t())) :: t()
  # @doc """
  # Function to introduce variables.

  # Example:

  #     iex> alias Reason.{Subst, Var, Goal}
  #     iex> g = Goal.call_fresh(
  #     ...>   :kiwi,
  #     ...>   fn fruit -> Goal.identical(:plum, fruit) end
  #     ...> ).(Subst.new())
  #     iex> w = Goal.stream_take(g, false)
  #     iex> assert length(w) == 1

  # """
  # def call_fresh(name, f), do: f.(Var.new(name))

  @doc """
  Returns the list of `n` substitutions that would make goal `g` succeed.

  Examples:

      iex> alias Reason.{Subst, Var, Goal}
      iex> x = Var.new()
      iex> g = Goal.disj(
      ...>   Goal.identical(x, :olive),
      ...>   Goal.identical(x, :oil)
      ...> )
      iex> assert length(Goal.run_goal(g, false)) == 2

  """
  @spec run_goal(t(), non_neg_integer() | false) :: [Subst.t()]
  def run_goal(g, n), do: stream_take(g.(Subst.new()), n)
end
