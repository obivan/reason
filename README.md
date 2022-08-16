# Reason

A simple functional implementation of the Minikanren language in Elixir.

## Installation

The package can be installed by adding `reason` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:reason, git: "https://github.com/obivan/reason.git", tag: "v0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
by running `mix docs`.

## Usage

Only the `Reason` module needs to be imported by the client code.
All other modules contain private implementation details.

## miniKanren

[miniKanren](https://en.wikipedia.org/wiki/MiniKanren) is a family of
programming languages for relational programming. Unlike functions,
relations are bidirectional. If miniKanren is given an expression and a
desired output, miniKanren can run the expression "backward", finding
all possible inputs to the expression that produce the desired output.

To distinguish between functions and relations, when we declare a
relation we conventionally use the suffix `o` or `e`.

For example, let's suppose we have an `append` function that takes two
lists as arguments, adds the contents of the second list to the end of
the first list, and returns the resulting concatenated list.

Let's define an `appendo` relation that will relate the arguments and
the result. Relations are defined by using the macro `defrel`:

```elixir
defmodule MyRelations do
  import Reason

  defrel appendo(l, s, out) do
    conde do
      _ ->
        identical(l, [])
        identical(s, out)

      [a, d, res] ->
        identical([a | d], l)
        identical([a | res], out)
        appendo(d, s, res)
    end
  end
end
```

We can use the relation in the same way as the `append` function - to concatenate lists.

```elixir
iex> import Reason

run q do
  MyRelations.appendo([1, 2], [:a, :b, :c], q)
end

# => [[1, 2, :a, :b, :c]]
```

But we can also use a relation to, for example, generate all possible
pairs of lists, which when concatenated will produce a given list:

```elixir
iex> import Reason

run [x, y] do
  MyRelations.appendo(x, y, [:a, :b, :c])
end

# => [
  [[], [:a, :b, :c]],
  [[:a], [:b, :c]],
  [[:a, :b], [:c]],
  [[:a, :b, :c], []]
]
```

For further reading, see http://minikanren.org

Now let's look at the solution to one of the
[Zebra Puzzle](https://en.wikipedia.org/wiki/Zebra_Puzzle)
variations as an example. The formulation of the riddle is as follows:

There are five houses in a row and in five different colors. In each
house lives a person from a different country. Each person drinks a
certain drink, plays a certain sport, and keeps a certain pet. No
two people drink the same drink, play the same sport, or keep
the same pet.

1. The Brit lives in a red house
2. The Swede keeps dogs
3. The Dane drinks tea
4. The green house is on the left of the white house
5. The green house owner drinks coffee
6. The person who plays polo rears birds
7. The owner of the yellow house plays hockey
8. The man living in the house right in the center drinks milk
9. The Norwegian lives in the first house
10. The man who plays baseball lives next to the man who keeps cats
11. The man who keeps horses lives next to the one who plays hockey
12. The man who plays billiards drinks beer
13. The German plays soccer
14. The Norwegian lives next to the blue house

Who owns the fish?
Who drinks water?

```elixir
defmodule ZebraPuzzle do

  import Reason
  
  # We represent a street as a list of houses, so we need a
  # relation `membero` that knows if an element is in the list.
  #
  # It is defined through the helper relations `hdo` and `tlo`
  # by analogy with `hd/1` and `tl/1`.
  defrel membero(x, l) do
    conde do
      _ ->
        hdo(l, x)

      t ->
        tlo(l, t)
        membero(x, t)
    end
  end

  defrel hdo(l, x) do
    fresh(t, do: identical([x | t], l))
  end

  defrel tlo(l, x) do
    fresh(h, do: identical([h | x], l))
  end

  # We also need a relation relating the house number to its position
  # in the list, with which we represent the street
  # (for facts number 8 and 9).
  defrel nth_houseo(n, street, house) do
    fresh [h1, h2, h3, h4, h5] do
      identical([:street, h1, h2, h3, h4, h5], street)

      conde do
        _ -> [identical(n, 1), identical(house, h1)]
        _ -> [identical(n, 2), identical(house, h2)]
        _ -> [identical(n, 3), identical(house, h3)]
        _ -> [identical(n, 4), identical(house, h4)]
        _ -> [identical(n, 5), identical(house, h5)]
      end
    end
  end

  # A relation determining that one house is to the left of the other
  defrel to_the_left_of(house_a, house_b, street) do
    fresh [h1, h2, h3, h4, h5] do
      identical([:street, h1, h2, h3, h4, h5], street)

      conde do
        _ -> [identical(h1, house_a), identical(h2, house_b)]
        _ -> [identical(h2, house_a), identical(h3, house_b)]
        _ -> [identical(h3, house_a), identical(h4, house_b)]
        _ -> [identical(h4, house_a), identical(h5, house_b)]
      end
    end
  end

  # And the relation that determines the fact of the neighborhood
  defrel next_to(x, y, l) do
    disj(do: [to_the_left_of(x, y, l), to_the_left_of(y, x, l)])
  end

  # We can now carefully describe the declarative solution
  defrel solve(street) do
    conj do
      # There are five houses
      fresh [h1, h2, h3, h4, h5] do
        identical([:street, h1, h2, h3, h4, h5], street)
      end

      # Brit lives in red house
      fresh [pet, drink, sport] do
        membero([:house, :brit, :red, pet, drink, sport], street)
      end

      # Swede keeps dogs
      fresh [color, drink, sport] do
        membero([:house, :swede, color, :dogs, drink, sport], street)
      end

      # Dane drinks tea
      fresh [color, pet, sport] do
        membero([:house, :dane, color, pet, :tea, sport], street)
      end

      # Green house owner drinks coffee
      fresh [nationality, pet, sport] do
        membero([:house, nationality, :green, pet, :coffee, sport], street)
      end

      # Polo player rears birds
      fresh [nationality, color, drink] do
        membero([:house, nationality, color, :birds, drink, :polo], street)
      end

      # Yellow house owner plays hockey
      fresh [nationality, pet, drink] do
        membero([:house, nationality, :yellow, pet, drink, :hockey], street)
      end

      # Billiad player drinks beer
      fresh [nationality, color, pet] do
        membero([:house, nationality, color, pet, :beer, :billiard], street)
      end

      # German plays soccer
      fresh [color, pet, drink] do
        membero([:house, :german, color, pet, drink, :soccer], street)
      end

      # Center house owner drinks milk
      fresh [nationality, color, pet, sport] do
        nth_houseo(3, street, [:house, nationality, color, pet, :milk, sport])
      end

      # Norvegian in first house
      fresh [color, pet, drink, sport] do
        nth_houseo(1, street, [:house, :norvegian, color, pet, drink, sport])
      end

      # Green house left of white house
      fresh [nationality1, pet1, drink1, sport1, nationality2, pet2, drink2, sport2] do
        to_the_left_of(
          [:house, nationality1, :green, pet1, drink1, sport1],
          [:house, nationality2, :white, pet2, drink2, sport2],
          street
        )
      end

      # Baseball player lives next to cat owner
      fresh [nationality1, color1, pet1, drink1, nationality2, color2, drink2, sport2] do
        next_to(
          [:house, nationality1, color1, pet1, drink1, :baseball],
          [:house, nationality2, color2, :cats, drink2, sport2],
          street
        )
      end

      # Hockey player lives next to horse owner
      fresh [nationality1, color1, pet1, drink1, nationality2, color2, drink2, sport2] do
        next_to(
          [:house, nationality1, color1, pet1, drink1, :hockey],
          [:house, nationality2, color2, :horses, drink2, sport2],
          street
        )
      end

      # Norvegian lives next to blue house
      fresh [color1, pet1, drink1, sport1, nationality2, pet2, drink2, sport2] do
        next_to(
          [:house, :norvegian, color1, pet1, drink1, sport1],
          [:house, nationality2, :blue, pet2, drink2, sport2],
          street
        )
      end

      # Somebody owns the fish
      fresh [color, drink, sport, nationality] do
        membero([:house, nationality, color, :fish, drink, sport], street)
      end

      # Somebody drinks water
      fresh [nationality, color, pet, sport] do
        membero([:house, nationality, color, pet, :water, sport], street)
      end
    end
  end
end
```

And now we can find out the solution:

```elixir
iex> import Reason

run q do
  ZebraPuzzle.solve(q)
end

# => [
  [
    :street,
    [:house, :norvegian, :yellow, :cats, :water, :hockey],
    [:house, :dane, :blue, :horses, :tea, :baseball],
    [:house, :brit, :red, :birds, :milk, :polo],
    [:house, :german, :green, :fish, :coffee, :soccer],
    [:house, :swede, :white, :dogs, :beer, :billiard]
  ]
]
```

## TODOs

- Relational arithmetic
- Elixir program synthesis capabilities (`evalo`, quines generation)
- Impure operators (like `conda`, `condu`, `project`)
- First-order miniKanren representation
- Time and memory limited execution
