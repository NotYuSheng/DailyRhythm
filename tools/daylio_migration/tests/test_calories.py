import csv
from collections import Counter

from daylio_migration.app_export import build
from daylio_migration.calories import accept, load_calories, write_calories


def test_only_answers_for_foods_asked_about_with_sane_numbers_are_kept():
    answer = [
        {"food": "chicken rice", "kcal": 607.4, "serving": "1 plate"},
        {"food": "Kopi", "kcal": 0},
        {"food": "Invented", "kcal": 300},
        {"food": "Haircut", "kcal": None},
        {"food": "Buffet", "kcal": 9000},
        "junk",
    ]
    out = accept(["Chicken rice", "Kopi", "Haircut", "Buffet"], answer)
    assert out == {"Chicken rice": {"kcal": 607, "serving": "1 plate"}, "Haircut": {"kcal": None, "serving": ""}}


def test_a_tidied_name_still_lines_up():
    foods = ["Chyrsthamum tea", "Teh tarik"]
    answer = [{"food": "Chrysanthemum tea", "kcal": 90}, {"food": "teh-tarik", "kcal": 150}]
    assert {k: v["kcal"] for k, v in accept(foods, answer).items()} == {"Chyrsthamum tea": 90, "Teh tarik": 150}
    # Out of step (an item missing): only exact names count.
    assert list(accept(foods, answer[:1] + [{"food": "Other", "kcal": 1}, {"food": "x", "kcal": 1}])) == []


def test_corrections_survive_a_rerun(tmp_path):
    path = tmp_path / "calories.csv"
    counts = Counter({"Chicken rice": 5, "Laksa": 2})
    cache = {"chicken rice": {"kcal": 600, "serving": "1 plate"}, "laksa": {"kcal": 590, "serving": "1 bowl"}}
    write_calories(path, counts, cache)
    rows = list(csv.DictReader(open(path)))
    rows[1]["kcal"] = "650"  # a person corrects laksa
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    hows = write_calories(path, counts, cache)
    assert load_calories(path) == {"chicken rice": {"kcal": 600.0, "how": "estimate"}, "laksa": {"kcal": 650.0, "how": "user"}}
    assert hows == Counter({"estimate": 1, "user": 1})


def test_foods_get_their_calories_and_source_in_the_export():
    day = {"date": "2024-03-05", "mood": 3, "wake": None, "bed": None, "journal": [], "activities": [],
           "food_sources": [], "symptoms": [], "exercises": [], "supplements": [], "entries": [],
           "meals": [{"text": "chicken rice 4", "name": "chicken rice", "canonical": "Chicken rice", "food": "Chicken rice",
                      "quantity": None, "price": 4, "currency": "SGD", "comment": None, "price_approx": False}]}
    files = build([day], None, {"chicken rice": {"kcal": 600.0, "how": "estimate"}})
    food = list(csv.DictReader(files["food_items.csv"].splitlines()))[0]
    assert (food["Kcal"], food["Kcal Source"]) == ("600", "estimate")


def test_common_foods_table_keeps_only_well_formed_entries():
    from daylio_migration.common_foods import clean

    items = [
        {"name": "Laksa", "aliases": ["curry laksa", "laksa", ""], "kcal": 589.6},
        {"name": "laksa", "kcal": 500},
        {"name": "Air", "kcal": 0},
        {"name": "Feast", "kcal": 5000},
        {"name": "", "kcal": 100},
        {"name": "Kopi", "kcal": "120"},
        "junk",
    ]
    assert clean(items) == [
        {"name": "Laksa", "aliases": ["curry laksa"], "kcal": 590},
        {"name": "Kopi", "aliases": [], "kcal": 120},
    ]
