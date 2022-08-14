defmodule ReasonTest do
  use ExUnit.Case

  doctest Reason
  doctest Reason.Var
  doctest Reason.Subst
  doctest Reason.Goal

  import Reason.Goal, only: [identical: 2]
  import Reason

  defrel appendo(l, s, out) do
    disj do
      conj do
        identical(l, [])
        identical(s, out)
      end

      fresh [a, d, res] do
        identical([a | d], l)
        identical([a | res], out)
        appendo(d, s, res)
      end
    end
  end

  test "appendo" do
    answer =
      run false, q do
        fresh [x, y] do
          appendo(x, y, [:a, :b, :c])
          identical(q, [x, y])
        end
      end

    assert answer == [
             [[], [:a, :b, :c]],
             [[:a], [:b, :c]],
             [[:a, :b], [:c]],
             [[:a, :b, :c], []]
           ]
  end

  defmodule ZebraPuzzle do
    # There are five houses in a row and in five different colors. In each
    # house lives a person from a different country. Each person drinks a
    # certain drink, plays a certain sport, and keeps a certain pet. No
    # two people drink the same drink, play the same sport, or keep
    # the same pet.

    # 1. The Brit lives in a red house
    # 2. The Swede keeps dogs
    # 3. The Dane drinks tea
    # 4. The green house is on the left of the white house
    # 5. The green house owner drinks coffee
    # 6. The person who plays polo rears birds
    # 7. The owner of the yellow house plays hockey
    # 8. The man living in the house right in the center drinks milk
    # 9. The Norwegian lives in the first house
    # 10. The man who plays baseball lives next to the man who keeps cats
    # 11. The man who keeps horses lives next to the one who plays hockey
    # 12. The man who plays billiards drinks beer
    # 13. The German plays soccer
    # 14. The Norwegian lives next to the blue house

    # Who owns the fish?
    # Who drinks water?

    defrel hdo(l, x) do
      fresh([t], do: identical([x | t], l))
    end

    defrel tlo(l, x) do
      fresh([h], do: identical([h | x], l))
    end

    defrel membero(x, l) do
      disj do
        hdo(l, x)

        fresh [t] do
          tlo(l, t)
          membero(x, t)
        end
      end
    end

    defrel nth_houseo(n, street, house) do
      fresh [h1, h2, h3, h4, h5] do
        identical([:street, h1, h2, h3, h4, h5], street)

        disj do
          conj(do: [identical(n, 1), identical(house, h1)])
          conj(do: [identical(n, 2), identical(house, h2)])
          conj(do: [identical(n, 3), identical(house, h3)])
          conj(do: [identical(n, 4), identical(house, h4)])
          conj(do: [identical(n, 5), identical(house, h5)])
        end
      end
    end

    defrel to_the_left_of(house_a, house_b, street) do
      fresh [h1, h2, h3, h4, h5] do
        identical([:street, h1, h2, h3, h4, h5], street)

        disj do
          conj(do: [identical(h1, house_a), identical(h2, house_b)])
          conj(do: [identical(h2, house_a), identical(h3, house_b)])
          conj(do: [identical(h3, house_a), identical(h4, house_b)])
          conj(do: [identical(h4, house_a), identical(h5, house_b)])
        end
      end
    end

    defrel next_to(x, y, l) do
      disj(do: [to_the_left_of(x, y, l), to_the_left_of(y, x, l)])
    end

    defrel solve(street) do
      conj do
        # There are five houses
        fresh [h1, h2, h3, h4, h5] do
          identical([:street, h1, h2, h3, h4, h5], street)
        end

        # Brit lives in red house
        fresh [pet, beverage, sport] do
          membero([:house, :brit, :red, pet, beverage, sport], street)
        end

        # Swede keeps dogs
        fresh [color, beverage, sport] do
          membero([:house, :swede, color, :dogs, beverage, sport], street)
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
        fresh [nationality, color, beverage] do
          membero([:house, nationality, color, :birds, beverage, :polo], street)
        end

        # Yellow house owner plays hockey
        fresh [nationality, pet, beverage] do
          membero([:house, nationality, :yellow, pet, beverage, :hockey], street)
        end

        # Billiad player drinks beer
        fresh [nationality, color, pet] do
          membero([:house, nationality, color, pet, :beer, :billiard], street)
        end

        # German plays soccer
        fresh [color, pet, beverage] do
          membero([:house, :german, color, pet, beverage, :soccer], street)
        end

        # Center house owner drinks milk
        fresh [nationality, color, pet, sport] do
          nth_houseo(3, street, [:house, nationality, color, pet, :milk, sport])
        end

        # Norvegian in first house
        fresh [color, pet, beverage, sport] do
          nth_houseo(1, street, [:house, :norvegian, color, pet, beverage, sport])
        end

        # Green house left of white house
        fresh [nationality1, pet1, beverage1, sport1, nationality2, pet2, beverage2, sport2] do
          to_the_left_of(
            [:house, nationality1, :green, pet1, beverage1, sport1],
            [:house, nationality2, :white, pet2, beverage2, sport2],
            street
          )
        end

        # Baseball player lives next to cat owner
        fresh [nationality1, color1, pet1, beverage1, nationality2, color2, beverage2, sport2] do
          next_to(
            [:house, nationality1, color1, pet1, beverage1, :baseball],
            [:house, nationality2, color2, :cats, beverage2, sport2],
            street
          )
        end

        # Hockey player lives next to horse owner
        fresh [nationality1, color1, pet1, beverage1, nationality2, color2, beverage2, sport2] do
          next_to(
            [:house, nationality1, color1, pet1, beverage1, :hockey],
            [:house, nationality2, color2, :horses, beverage2, sport2],
            street
          )
        end

        # Norvegian lives next to blue house
        fresh [color1, pet1, beverage1, sport1, nationality2, pet2, beverage2, sport2] do
          next_to(
            [:house, :norvegian, color1, pet1, beverage1, sport1],
            [:house, nationality2, :blue, pet2, beverage2, sport2],
            street
          )
        end

        # Somebody owns the fish
        fresh [color, beverage, sport, nationality] do
          membero([:house, nationality, color, :fish, beverage, sport], street)
        end

        # Somebody drinks water
        fresh [nationality, color, pet, sport] do
          membero([:house, nationality, color, pet, :water, sport], street)
        end
      end
    end
  end

  test "zebra puzzle" do
    answer =
      run 10, q do
        ZebraPuzzle.solve(q)
      end

    assert Enum.sort(answer) ==
             Enum.sort([
               [
                 :street,
                 [:house, :norvegian, :yellow, :cats, :water, :hockey],
                 [:house, :dane, :blue, :horses, :tea, :baseball],
                 [:house, :brit, :red, :birds, :milk, :polo],
                 [:house, :german, :green, :fish, :coffee, :soccer],
                 [:house, :swede, :white, :dogs, :beer, :billiard]
               ]
             ])
  end
end
