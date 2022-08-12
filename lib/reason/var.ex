defmodule Reason.Var do
  @moduledoc """
  A logic variable.

  Basically a unique reference that can optionally have a name.
  """

  @enforce_keys [:id]
  defstruct [:sym, :id]

  @typedoc "A logic variable name. Could be an atom, a string or nil."
  @type name :: atom() | String.t() | nil

  @typedoc "A logic variable."
  @type t :: %__MODULE__{sym: name(), id: reference()}

  @doc """
  Returns a new anonymous logic variable. See `new/1` for documentation.
  """
  @spec new() :: t()
  def new(), do: %__MODULE__{id: make_ref()}

  @doc """
  Returns a new named logic variable.
  The name could be an atom or a string.

  Anonymous variables are always different:

      iex> alias Reason.Var
      iex> v1 = Var.new()
      iex> v2 = Var.new()
      iex> v1 == v2
      false

  Named variables are also always different, even if they
  have the same name:

      iex> alias Reason.Var
      iex> v1 = Var.new(:olive)
      iex> v2 = Var.new(:olive)
      iex> v1 == v2
      false

  Only comparison of a variable to itself gives the logical truth:

      iex> alias Reason.Var
      iex> v1 = Var.new()
      iex> v1 == v1
      true
      iex> v2 = v1
      iex> v1 == v2
      true

  """
  @spec new(name()) :: t()
  def new(name) when is_atom(name) or is_binary(name) do
    %__MODULE__{id: make_ref(), sym: name}
  end

  @doc "Conveniently creates several variables at a time."
  @spec new_many([name()]) :: [t()]
  def new_many([]), do: []
  def new_many([h | t]), do: [new(h) | new_many(t)]
end

defimpl String.Chars, for: Var do
  alias Reason.Var

  def to_string(%Var{sym: nil, id: id}), do: "var_#{inspect(id)}"
  def to_string(%Var{sym: s, id: _}), do: "#{s}"
end

defimpl Inspect, for: Var do
  alias Reason.Var

  def inspect(%Var{sym: nil, id: id}, _opts), do: "var_#{inspect(id)}"
  def inspect(%Var{sym: s, id: id}, _opts), do: "#{s}(#{inspect(id)})"
end
