import csv
import io

from daylio_migration.app_export import build


def rows(files, name):
    return list(csv.DictReader(io.StringIO(files[name])))


DAYS = [
    {"date": "2024-03-01", "mood": 3, "wake": "07:00", "bed": "23:30", "journal": [], "activities": [],
     "food_sources": [], "symptoms": [], "meals": [], "exercises": [], "supplements": [], "entries": []},
    {
        "date": "2024-03-02", "mood": 3, "wake": "07:00", "bed": "01:50",
        "activities": ["Study"], "food_sources": ["Takeout"], "symptoms": ["Anxiety"],
        "meals": [
            {"text": "wanton mee 3.5", "name": "wanton mee", "canonical": "Wanton noodles", "quantity": None,
             "price": 3.5, "currency": "SGD", "comment": None, "price_approx": False},
            {"text": "Rice x1.5 22usd (big)", "name": "Rice", "quantity": 1.5, "price": 22, "currency": "USD",
             "comment": "big", "price_approx": False},
        ],
        "supplements": [{"text": "2 protein", "name": "protein", "quantity": 2}],
        "exercises": [
            {"text": "60 sit ups", "name": "sit ups", "canonical": "Situps", "reps": 60, "sets": None, "weight_kg": None,
             "duration_min": None, "distance_km": None, "steps": None},
            {"text": "jog 5.66km 40min", "name": "jog", "reps": None, "sets": None, "weight_kg": None, "duration_min": 40,
             "distance_km": 5.66, "steps": None},
        ],
        "entries": [
            {"date": "2024-03-02", "time": "18:00", "mood": 2, "activities": ["backpain"], "note": "Unproductive"},
            {"date": "2024-03-03", "time": "01:00", "mood": 3, "activities": [], "note": "Wake 7am\nwanton mee 3.5"},
        ],
        "journal": [
            {"text": "Unproductive", "mood": 2, "time": "18:00", "tags": ["Back Pain"]},
            {"text": "Wistful", "mood": None, "time": "23:59", "tags": []},
        ],
    },
]


def test_sleep_total_uses_previous_bedtime():
    sleep = rows(build(DAYS), "sleep_entries.csv")
    assert sleep[1]["Total Hours"] == "7.5"  # 23:30 -> 07:00
    assert sleep[1]["Sleep Time"] == "2024-03-02T01:50:00.000"


def test_meals_link_to_canonical_food_and_keep_the_original_line():
    files = build(DAYS)
    meals = rows(files, "meal_entries.csv")
    assert [m["Name"] for m in meals] == ["Wanton noodles", "Rice", "protein"]
    assert [m["Time"][11:16] for m in meals] == ["12:00", "12:01", "12:02"]
    assert {m["Time Known"] for m in meals} == {"0"}
    assert (meals[0]["Food Item"], meals[0]["Raw Text"]) == ("Wanton noodles", "wanton mee 3.5")
    rice = meals[1]
    assert (rice["Quantity"], rice["Price"], rice["Currency"], rice["Notes"]) == ("2", "22", "USD", "quantity 1.5; big")
    assert meals[2]["Tags"] == "Supplement"

    foods = {f["Name"]: f for f in rows(files, "food_items.csv")}
    assert foods["Wanton noodles"]["Aliases"] == "wanton mee"
    assert foods["Wanton noodles"]["Last Price"] == "3.5"
    assert foods["Rice"]["Last Price"] == "", "only SGD prices are a last price"


def test_exercises_cardio_as_run():
    files = build(DAYS)
    ex = rows(files, "exercise_entries.csv")
    assert (ex[0]["Type"], ex[0]["Equipment Type"], ex[0]["Reps"]) == ("weightLifting", "bodyweight", "60")
    assert (ex[0]["Exercise Item"], ex[0]["Raw Text"]) == ("Situps", "60 sit ups")
    assert (ex[1]["Type"], ex[1]["Distance"], ex[1]["Duration Seconds"]) == ("run", "5.66", "2400")
    items = {x["Name"]: x for x in rows(files, "exercise_items.csv")}
    assert (items["Situps"]["Aliases"], items["Situps"]["Category"]) == ("sit ups", "strength")
    assert items["jog"]["Category"] == "cardio"


def test_moments_become_journal_entries_with_tags():
    files = build(DAYS)
    assert rows(files, "mood_entries.csv")[1]["Notes"] == ""
    journal = rows(files, "journal_entries.csv")
    assert [(j["Text"], j["Mood"], j["Time"][11:16], j["Tag Names"]) for j in journal] == [
        ("Unproductive", "2", "18:00", "Back Pain"), ("Wistful", "", "23:59", ""),
    ]
    assert {j["Source"] for j in journal} == {"daylio"}
    names = {a["Tag Name"] for a in rows(files, "activity_entries.csv")}
    assert names == {"Study", "Takeout", "Anxiety"}
    tags = {t["Name"]: (t["Category"], t["Kind"]) for t in rows(files, "tags.csv")}
    assert tags["Takeout"] == ("Food Source", "food_source")
    assert tags["Anxiety"] == ("Health", "symptom")
    assert tags["Back Pain"] == ("Health", "symptom"), "tags used only by moments are exported too"
    assert tags["Study"][1] == "activity"


def test_original_entries_are_kept_verbatim():
    raw = rows(build(DAYS), "daylio_raw.csv")
    assert [(r["Date"][:10], r["Logged Time"], r["Activities"], r["Note"]) for r in raw] == [
        ("2024-03-02", "18:00", "backpain", "Unproductive"),
        ("2024-03-02", "01:00", "", "Wake 7am\nwanton mee 3.5"),
    ], "entries keep the logical day they were assigned to"


def test_garmin_metrics_and_workouts():
    garmin = [{"date": "2024-03-02", "source": "garmin_export", "metrics": {"steps": 9000, "stress_avg": 31},
               "workouts": [{"type": "running", "start": "2024-03-02T20:31", "duration_min": 17.7, "distance_km": 2.38,
                             "kcal": 200, "avg_hr": 153.0, "max_hr": None}]}]
    files = build(DAYS, garmin)
    assert [(m["Metric"], m["Value"]) for m in rows(files, "health_metrics.csv")] == [("steps", "9000"), ("stress_avg", "31")]
    workout = rows(files, "health_workouts.csv")[0]
    assert (workout["Start"], workout["Max HR"], workout["Source"]) == ("2024-03-02T20:31:00.000", "", "garmin_export")
    assert "health_metrics.csv" not in build(DAYS), "no empty files without Garmin data"


def _day(**overrides):
    day = {"date": "2024-03-05", "mood": 3, "wake": None, "bed": None, "journal": [], "activities": [],
           "food_sources": [], "symptoms": [], "meals": [], "exercises": [], "supplements": [], "entries": []}
    return {**day, **overrides}


def _exercise(**overrides):
    x = {"text": "", "name": "", "reps": None, "sets": None, "weight_kg": None, "duration_min": None,
         "distance_km": None, "steps": None}
    return {**x, **overrides}


def test_exercises_with_only_a_distance_or_time_are_kept():
    files = build([_day(exercises=[_exercise(text="5km", distance_km=5.0), _exercise(text="30 mins", duration_min=30)])])
    ex = rows(files, "exercise_entries.csv")
    assert [(x["Exercise Name"], x["Type"]) for x in ex] == [("Run", "run"), ("Workout", "weightLifting")]
    assert ex[1]["Notes"] == "duration_min 30"


def test_exercise_notes_hold_only_what_the_columns_dont():
    files = build([_day(exercises=[
        _exercise(name="walk", distance_km=3.0, steps=4000),
        _exercise(name="curl", weight_kg=10, reps=12),
    ])])
    walk, curl = rows(files, "exercise_entries.csv")
    assert walk["Notes"] == "steps 4000"
    assert (curl["Weight"], curl["Notes"]) == ("10", "")


def test_moments_after_midnight_sort_last():
    files = build([_day(journal=[{"text": "Late", "mood": 3, "time": "01:10", "tags": [], "next_day": True}])])
    assert rows(files, "journal_entries.csv")[0]["Time"] == "2024-03-06T01:10:00.000"


def _meal(text, name, price, food=None):
    from daylio_migration.spending import spending_kind

    return {"text": text, "name": name, "canonical": None, "food": food, "quantity": None, "price": price,
            "currency": "SGD", "comment": None, "price_approx": False, "spending": spending_kind(name, price)}


def test_events_and_gifts_go_to_spending_not_meals():
    files = build([_day(meals=[
        _meal("Zhi's wedding 288", "Zhi's wedding", 288),
        _meal("Paradise hotpot team farewell 187", "Paradise hotpot team farewell", 187),
        _meal("Farewell lunch", "Farewell lunch", None),
        _meal("Chicken rice 4", "Chicken rice", 4),
        _meal("Party wings 9", "Party wings", 9),
    ])])
    spending = rows(files, "spending_entries.csv")
    assert [(s["Label"], s["Amount"], s["Category"]) for s in spending] == [
        ("Zhi's wedding", "288", "gift"), ("Paradise hotpot team farewell", "187", "event"),
    ]
    assert [m["Name"] for m in rows(files, "meal_entries.csv")] == ["Farewell lunch", "Chicken rice", "Party wings"], \
        "unpriced is still a meal"


def test_a_plate_links_to_its_base_dish_and_keeps_its_full_name():
    files = build([_day(meals=[_meal("Vegetarian maggie with long beans 5", "Vegetarian maggie with long beans", 5,
                                     food="Vegetarian maggie")])])
    meal = rows(files, "meal_entries.csv")[0]
    assert (meal["Name"], meal["Food Item"]) == ("Vegetarian maggie with long beans", "Vegetarian maggie")
    foods = {f["Name"]: f for f in rows(files, "food_items.csv")}
    assert foods["Vegetarian maggie"]["Last Price"] == "", "the plate's price isn't the dish's"
