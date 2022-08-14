defmodule Reason do
  @moduledoc """
  First-order miniKanren for Elixir.
  """

  alias Reason.{Goal, Subst, Var}

  defdelegate identical(g1, g2), to: Goal

  @doc """
  Compiles `disj(g1, g2, g3)` to `Goal.disj(Goal.disj(g1, g2), g3)`.

  Example:

      iex> ast = quote do: Reason.disj(do: [g1, g2, g3])
      iex> ast |> Macro.expand(__ENV__) |> Macro.to_string()
      "Goal.disj(Goal.disj(g1, g2), g3)"

      iex> ast = quote do: Reason.disj(do: [g1])
      iex> ast |> Macro.expand(__ENV__) |> Macro.to_string()
      "g1"

      iex> alias Reason.{Subst, Var}
      iex> g = Reason.disj(do: [])
      iex> x = Var.new()
      iex> s = Subst.put(Subst.new(), x, :olive)
      iex> assert g.(s) == []

  """
  # Enum.reduce([:g1, :g2, :g3], fn g, acc -> [acc | [g]] end)
  defmacro disj(do: block) do
    case take_goals(block) do
      [] ->
        quote(do: Goal.fail())

      [_ | _] = goals ->
        Enum.reduce(goals, fn
          g, acc -> quote do: Goal.disj(unquote(acc), unquote(g))
        end)
    end
  end

  @doc """
  Compiles `conj(g1, g2, g3)` to `Goal.conj(Goal.conj(g1, g2), g3)`.

  Example:

      iex> ast = quote do: Reason.conj(do: [g1, g2, g3])
      iex> ast |> Macro.expand(__ENV__) |> Macro.to_string()
      "Goal.conj(Goal.conj(g1, g2), g3)"

      iex> ast = quote do: Reason.conj(do: [g1])
      iex> ast |> Macro.expand(__ENV__) |> Macro.to_string()
      "g1"

      iex> alias Reason.{Subst, Var}
      iex> g = Reason.conj(do: [])
      iex> x = Var.new()
      iex> s = Subst.put(Subst.new(), x, :olive)
      iex> assert g.(s) == [%{x => :olive}]

  """
  defmacro conj(do: block) do
    case take_goals(block) do
      [] ->
        quote(do: Goal.succeed())

      [_ | _] = goals ->
        Enum.reduce(goals, fn
          g, acc -> quote do: Goal.conj(unquote(acc), unquote(g))
        end)
    end
  end

  @doc """
  Introduce vars.

  Examples:

      iex> alias Reason.Goal
      iex> Reason.fresh [x, y] do
      ...>   Goal.identical(x, :olive)
      ...>   Goal.identical(y, x)
      ...> end

  """
  defmacro fresh(vars, do: block) do
    vars = take_vars(vars)
    goals = take_goals(block)

    quote do
      unquote_splicing(introduce_vars(vars))
      Reason.conj(do: unquote(goals))
    end
  end

  @doc """
  Run goals.

      iex> alias Reason.{Goal, Var}
      iex> require Reason
      iex> Reason.run 1, q do
      ...>   Reason.fresh [x, y] do
      ...>     Goal.identical(x, :olive)
      ...>     Goal.identical(y, x)
      ...>     Goal.identical(q, y)
      ...>   end
      ...> end
      [:olive]

  """

  defmacro run(n, v, do: block) do
    quote do
      g = Reason.fresh([unquote(v)], do: unquote(block))
      s = Goal.run_goal(g, unquote(n))
      Enum.map(s, Subst.reify(unquote(v)))
    end
  end

  defp introduce_vars(stx) do
    for {name, _, _} = var <- stx do
      quote do: unquote(var) = Var.new(unquote(name))
    end
  end

  defp take_goals(stx) do
    case stx do
      {:__block__, _, goals} -> Enum.flat_map(goals, &take_goals/1)
      goals when is_list(goals) -> Enum.flat_map(goals, &take_goals/1)
      goal -> [goal]
    end
  end

  @doc """
  Define custom relation.
  """
  defmacro defrel(call, do: block) do
    {fn_name, _, args} = call

    quote do
      def unquote(fn_name)(unquote_splicing(args)) do
        fn subst -> Reason.conj(do: unquote(block)).(subst) end
      end
    end
  end

  @doc """
  Sugar for disj(conj(g1, g2), conj(g3, g4))
  """
  defmacro conde(do: block) do
    disjuncts =
      for {:->, _, [vars, clauses]} <- block do
        quote do
          Reason.fresh(unquote(vars), do: unquote(clauses))
        end
      end

    quote do
      Reason.disj(do: unquote(disjuncts))
    end
  end

  defp take_vars(stx) do
    case stx do
      {:_, _, _} -> []
      # {:{}, _, vars} -> vars
      # {var1, var2} -> [var1, var2]
      {name, _, _} = var when is_atom(name) -> [var]
      l when is_list(l) -> Enum.flat_map(l, &take_vars/1)
    end
  end
end
