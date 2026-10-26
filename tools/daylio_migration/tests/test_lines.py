from daylio_migration.lines import parse_exercise, parse_lines, parse_meal, parse_time_line


def test_time_lines_and_typos():
    assert parse_time_line("0700 Reveille")[:2] == ("wake", "07:00")
    assert parse_time_line("0800 Reveill")[:2] == ("wake", "08:00")
    assert parse_time_line("0150 Sleep ")[:2] == ("bed", "01:50")
    assert parse_time_line("0300 Reveille PDT")[2] == "PDT"
    assert parse_time_line("0200 UST Sleep")[:3] == ("bed", "02:00", "UST")
    assert parse_time_line("070015 Reveille")[1] == "07:00"
    assert parse_time_line("Wanton noodles 3.50") is None


def test_meal_prices():
    meal = parse_meal("Wanton noodles 3.50", [])
    assert (meal.name, meal.price, meal.quantity) == ("Wanton noodles", 3.5, None)
    assert parse_meal("Popeyes 12", []).price == 12
    assert parse_meal("9\" US chicken classic pizza $15", []).price == 15
    assert parse_meal("Stuffs ~8", []).price_approx
    assert parse_meal("Us pizza pepperoni 9 inch 13.90", []).price == 13.9


def test_meal_currency_and_comment():
    flags = []
    meal = parse_meal("Ihop 22 usd", flags)
    assert (meal.price, meal.currency) == (22, "USD")
    meal = parse_meal("In and out USD 11.60", flags)
    assert (meal.name, meal.price, meal.currency) == ("In and out", 11.6, "USD")
    meal = parse_meal("Fish soup rice $130 ringgit (Kampong pricing)", flags)
    assert (meal.price, meal.currency, meal.comment) == (130, "MYR", "Kampong pricing")
    assert {f.code for f in flags} == {"foreign_currency"}


def test_meal_quantities():
    assert parse_meal("X2 Mee Hoon kuey", []).quantity == 2
    assert parse_meal("X1.5 Rice with minced pork", []).quantity == 1.5
    prata = parse_meal("X2 plain X1 egg 4.20", [])
    assert (prata.quantity, prata.price, prata.comment) == (3, 4.2, "2 plain, 1 egg")
    # Names that start with a number are not counts
    assert parse_meal("7 eleven baked rice $7", []).quantity is None
    assert parse_meal("X1 7 up", []).name == "7 up"


def test_exercises():
    ex = parse_exercise("60 situps")
    assert (ex.name, ex.reps) == ("situps", 60)
    ex = parse_exercise("3 sets x10 Romanian Dumbbell Deadlifts (Hamstrings)")
    assert (ex.sets, ex.reps, ex.name) == (3, 10, "Romanian Dumbbell Deadlifts")
    ex = parse_exercise("40 mins jog, 5.66 km")
    assert (ex.duration_min, ex.distance_km, ex.name) == (40, 5.66, "jog")
    assert parse_exercise("28k steps").steps == 28000
    assert parse_exercise("X3 sets dumbbell squats").sets == 3
    assert parse_exercise("Plank").reps is None


def test_note_zones():
    note = parse_lines([
        "0700 Reveille", "Wanton noodles 3.50", "X2 protein", "Apple",
        "0150 Sleep", "60 situps", "Plank", "Wistful, unsettled, poor work decisions",
    ])
    assert (note.wake, note.bed) == ("07:00", "01:50")
    assert [m.name for m in note.meals] == ["Wanton noodles", "Apple"]
    assert [s.name for s in note.supplements] == ["protein"]
    assert [e.name for e in note.exercises] == ["situps", "Plank"]
    assert note.journal == ["Wistful, unsettled, poor work decisions"]
    assert note.flags == []


def test_items_after_a_time_on_the_same_line():
    note = parse_lines(["0630 Reveille Burger king 5.50", "0035 Sleep Dumbbell curl to overhead press"])
    assert [m.name for m in note.meals] == ["Burger king"]
    assert [e.name for e in note.exercises] == ["Dumbbell curl to overhead press"]


def test_note_without_sleep_line_uses_content():
    note = parse_lines(["Feeling well rested and energetic"])
    assert note.journal == ["Feeling well rested and energetic"]
    note = parse_lines(["50 decline sit ups", "Mixed rice"])
    assert [e.name for e in note.exercises] == ["decline sit ups"]
    assert [m.name for m in note.meals] == ["Mixed rice"]
    assert {f.code for f in note.flags} == {"guessed_meal"}
