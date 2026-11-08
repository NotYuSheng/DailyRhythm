from daylio_migration.free_food import mark_free
from daylio_migration.lines import parse_meal
from daylio_migration.model import Day


def day(date, *meals, sources=()):
    return Day(date=date, mood=None, entries=[], food_sources=list(sources), meals=[parse_meal(m, []) for m in meals])


def priced(d):
    return [(m.name, m.price, m.comment) for m in d.meals]


def test_canteens_buffets_and_cookhouse_are_free_when_unpriced():
    d = day("2024-10-03", "Safti laksa", "Cookhouse chicken rice", "Lunch buffet", "Hotel buffet 29", "Nasi lemak")
    assert mark_free([d]) == 3
    assert priced(d) == [
        ("Safti laksa", 0, "free"),
        ("Cookhouse chicken rice", 0, "rations"),
        ("Lunch buffet", 0, "free"),
        ("Hotel buffet", 29, None),
        ("Nasi lemak", None, None),
    ]


def test_the_only_unpriced_meal_on_a_free_food_day():
    d = day("2024-10-17", "Chicken rice", "Wing rice 4.80", "Creatine", sources=["Free Food"])
    mark_free([d])
    assert priced(d)[:2] == [("Chicken rice", 0, "free"), ("Wing rice", 4.8, None)]
    assert d.meals[2].price is None, "a supplement isn't the free meal"


def test_unclear_or_already_labelled_free_food_days_are_left():
    several = day("2024-10-18", "Nasi lemak", "Curry chicken rice", sources=["Free Food"])
    labelled = day("2024-10-19", "Pc nuggets free", "Kopi", sources=["Free Food"])
    untagged = day("2024-10-20", "Chicken rice")
    assert mark_free([several, labelled, untagged]) == 0


def test_confirmed_meals_from_the_private_list():
    d = day("2024-02-17", "Cake", "Cake")
    other = day("2024-02-18", "Cake")
    assert mark_free([d, other], {("2024-02-17", "cake")}) == 2
    assert other.meals[0].price is None
