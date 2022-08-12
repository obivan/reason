defmodule Reason.Subst do
  @moduledoc """
  A substitution.

  _Substitution_ is a mapping between logic variables and values
  (also called terms).

  These substitutions are known as triangular substitutions (as opposed
  to the more common "idempotent representation").
  For more on these substitutions see Franz Baader and Wayne Snyder
  "Unification theory".

  One advantage of triangular substitutions is that they can be easily
  extended, without side-effecting or rebuilding the substitution.
  This lack of side-effects permits sharing of substitutions, while
  substitution extension remains a constant-time operation.
  This sharing, in turn, gives us backtracking for free.
  The major disadvantage is that variable lookup is both more
  complicated and more expensive than with idempotent substitutions.
  """

  @typedoc """
  The substitution is represented by a map whose keys are
  logic variables and whose values are terms (which may be itself
  a variable or a value that contains zero or more variables).
  We call such a pair of values an _association_.
  """
  # TODO: Investigate lookup time.
  #       Maybe a list of pairs for sharing prefixes?
  #       Trie? ETS table?
  @type t :: map()

  alias Reason.Var

  @doc """
  Creates a new empty substitution.
  """
  # Analogue of empty_s
  @spec new() :: t()
  def new(), do: Map.new()

  @doc """
  Unconditionally extends the substitution `subst`.
  Can introduce circularity. See also `put/3` documentation.
  """
  # Analogue of ext_s_no_check
  @spec put_unsafe(t(), Var.t(), term()) :: t()
  def put_unsafe(subst, x, v), do: Map.put(subst, x, v)

  @doc """
  Looks for the value of a logical variable `x` in
  the substitution `subst`.

  If, when walking a variable `x` in a substitution `subst`, we
  find that `x` is bound to another variable `v`, we must then
  walk `v` in the original substitution `subst`. If a `x` is not
  found (unassociated), we return its value.

  If a variable has been walk'd in a substitution and walk
  has produced a variable `w` then we know that `w` is _fresh_.

  Examples:

      iex> alias Reason.{Subst, Var}
      iex> s = Subst.new()
      iex> x = Var.new()
      iex> s = Subst.put(s, x, 5)
      iex> Subst.walk(s, x)
      5

      iex> alias Reason.{Subst, Var}
      iex> s = Subst.new()
      iex> [x, y, z] = Var.new_many([:x, :y, :z])
      iex> s = Subst.put(s, x, y)
      iex> s = Subst.put(s, y, z)
      iex> s = Subst.put(s, z, 5)
      %{x => y, y => z, z => 5}
      iex> Subst.walk(s, x)
      5

      iex> alias Reason.{Subst, Var}
      iex> s = Subst.new()
      iex> [x, y] = Var.new_many([:x, :y])
      iex> s = Subst.put(s, x, y)
      iex> v = Subst.walk(s, x)
      iex> assert v == y

  """
  def walk(subst, %Var{} = x) do
    case Map.fetch(subst, x) do
      {:ok, v} -> walk(subst, v)
      :error -> x
    end
  end

  # Otherwise `x` is bound to the term, so just return `x`.
  def walk(_subst, x), do: x

  @doc """
  Returns true if adding an association between `x` and `v` would
  introduce a circularity in a `subst` substitution.
  See also `put/3` documentation.
  """
  def occurs?(subst, x, v) do
    case walk(subst, v) do
      %Var{} = w -> w == x
      [h | t] -> occurs?(subst, x, h) or occurs?(subst, x, t)
      _ -> false
    end
  end

  @doc """
  `walk/2` is not primitive recursive - in fact, walk can diverge if
  used on a substitution containing a circularity. For example, when
  walking `x` in either the substitution `%{x => x}`
  or `%{y => x, x => y}`.

  To prevent circularities from being introduced, we extend the
  substitution using `put/3` rather than `put_unsafe/3`.

  `put/3` calls the `occurs?/3`, which returns true if adding an
  association between `x` and `v` would introduce a circularity.
  If so, `put/3` returns false instead of an extended substitution,
  indicating that unification has failed.

  Examples:

      iex> alias Reason.{Subst, Var}
      iex> s = Subst.new()
      iex> x = Var.new()
      iex> Subst.put(s, x, x)
      false

      iex> alias Reason.{Subst, Var}
      iex> s = Subst.new()
      iex> [x, y, z] = Var.new_many([:x, :y, :z])
      iex> s = Subst.put(s, x, y)
      iex> s = Subst.put(s, y, z)
      %{x => y, y => z}
      iex> Subst.put(s, z, x)
      false

      iex> alias Reason.{Subst, Var}
      iex> s = Subst.new()
      iex> [x, y, z, w] = Var.new_many([:x, :y, :z, :w])
      iex> s = Subst.put(s, x, [:a, y])
      iex> s = Subst.put(s, z, w)
      %{x => [:a, y], z => w}
      iex> Subst.put(s, y, [x])
      false

  """
  # Analogue of ext_s
  @spec put(t(), Var.t(), term()) :: t() | false
  def put(subst, %Var{} = x, v) do
    case occurs?(subst, x, v) do
      true -> false
      _ -> put_unsafe(subst, x, v)
    end
  end

  @doc """
  Unifies two terms `u` and `v` with respect to a substitution `subst`,
  returning a (potentially extended) substitution if unification
  succeeds, and returning false if unification fails
  or would introduce a circularity.
  """
  def unify(subst, u, v) do
    u = walk(subst, u)
    v = walk(subst, v)
    unify_ground(subst, u, v)
  end

  # Unifies two ground (walked) terms `u` and `v`.
  defp unify_ground(subst, u, v) when u == v, do: subst

  # Slight optimization. This clause can be safely commented out.
  #
  # If a variable has been walk'd in a substitution and walk
  # has produced a variable `w` then we know that `w` is fresh.
  # So we know that `u` and `v` are both fresh and do not need a
  # circularity check. This fact allows us to use `put_unsafe/3`.
  #
  # The call to `occurs?/3` from within `put/3` is potentially
  # expensive, since it must perform a complete tree walk on
  # its second argument.
  defp unify_ground(subst, %Var{} = u, %Var{} = v),
    do: put_unsafe(subst, u, v)

  defp unify_ground(subst, %Var{} = u, v), do: put(subst, u, v)
  defp unify_ground(subst, u, %Var{} = v), do: put(subst, v, u)

  defp unify_ground(subst, [hu | tu] = u, [hv | tv] = v)
       when is_list(u) and is_list(v) do
    s = unify(subst, hu, hv)
    s && unify(s, tu, tv)
  end

  defp unify_ground(_subst, _u, _v), do: false

  @spec reify_name(non_neg_integer()) :: String.t()
  defp reify_name(n), do: "_#{n}"

  @doc """
  Deep walk value in the substitution.

  If a value is deep walke'd in a substitution `subst`, and deep_walk
  produces a value `v`, then we know that each variable in `v` is fresh.

  Example:

      iex> alias Reason.{Subst, Var}
      iex> s = Subst.new()
      iex> [x, y, z, w] = Var.new_many([:x, :y, :z, :w])
      iex> s = Subst.put(s, x, :b)
      iex> s = Subst.put(s, z, y)
      iex> s = Subst.put(s, w, [x, :e, z])
      %{x => :b, z => y, w => [x, :e, z]}
      iex> Subst.deep_walk(s, w)
      [:b, :e, y]

  """
  @spec deep_walk(t(), term()) :: term()
  def deep_walk(subst, v) do
    case walk(subst, v) do
      %Var{} = v -> v
      [h | t] -> [deep_walk(subst, h) | deep_walk(subst, t)]
      v -> v
    end
  end

  @spec reify_s(t(), term()) :: t()
  defp reify_s(s, v) do
    case walk(s, v) do
      %Var{} = v -> put_unsafe(s, v, reify_name(map_size(s)))
      [h | t] -> reify_s(reify_s(s, h), t)
      _ -> s
    end
  end

  @doc """
  Takes a value `v` and produces a function that takes a substitution
  and reifies `v` using the given substitution.

  Examples:

      iex> alias Reason.{Subst, Var, Goal}
      iex> x = Var.new()
      iex> r = Subst.reify(x)
      iex> g = Goal.disj(
      ...>   Goal.identical(x, :olive),
      ...>   Goal.identical(x, :oil)
      ...> )
      iex> Enum.map(g.(Subst.new()), r)
      [:olive, :oil]

      iex> alias Reason.{Subst, Var}
      iex> s = Subst.new()
      iex> [x, y, z, w, v, u] = Var.new_many([:x, :y, :z, :w, :v, :u])
      iex> s = Subst.put(s, x, [u, w, y, z, [:ice, z]])
      iex> s = Subst.put(s, y, :corn)
      iex> s = Subst.put(s, w, [v, u])
      iex> Subst.reify(x).(s)
      ["_0", ["_1", "_0"], :corn, "_2", [:ice, "_2"]]

  """
  @spec reify(term()) :: (t() -> t())
  def reify(v) do
    fn s ->
      v = deep_walk(s, v)
      r = reify_s(new(), v)
      deep_walk(r, v)
    end
  end
end
