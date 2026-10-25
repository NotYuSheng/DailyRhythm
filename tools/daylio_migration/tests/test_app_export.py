import csv
import io

from daylio_migration.app_export import build


def rows(files, name):
    return list(csv.DictReader(io.StringIO(files[name])))


DAYS = [
    {"date": "2024-03-01", "mood": 3, "wake": "07:00", "bed": "23:30", "journal": [], "activities": [],
     "food_sources": [], "symptoms": [], "meals": [], "exercises": [], "supplements": []},
    {
        "date": "2024-03-02", "mood": 3, "wake": "07:00", "bed": "01:50",
        "activities": ["Study"], "food_sources": ["Takeout"], "symptoms": ["Anxiety"],
        "meals": [
            {"name": "Wanton noodles", "quantity": None, "price": 3.5, "currency": "SGD", "comment": None, "price_approx": False},
            {"name": "Rice", "quantity": 1.5, "price": 22, "currency": "USD", "comment": "big", "price_approx": False},
        ],
        "supplements": [{"name": "protein", "quantity": 2}],
        "exercises": [
            {"name": "situps", "reps": 60, "sets": None, "weight_kg": None, "duration_min": None, "distance_km": None, "steps": None},
            {"name": "jog", "reps": None, "sets": None, "weight_kg": None, "duration_min": 40, "distance_km": 5.66, "steps": None},
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


def test_meals_keep_order_and_fold_what_the_schema_lacks():
    meals = rows(build(DAYS), "meal_entries.csv")
    assert [m["Name"] for m in meals] == ["Wanton noodles", "Rice", "protein"]
    assert [m["Time"][11:16] for m in meals] == ["12:00", "12:01", "12:02"]
    rice = meals[1]
    assert (rice["Quantity"], rice["Price"], rice["Notes"]) == ("2", "", "quantity 1.5; big; 22 USD")
    assert meals[2]["Tags"] == "Supplement"


def test_exercises_cardio_as_run():
    ex = rows(build(DAYS), "exercise_entries.csv")
    assert (ex[0]["Type"], ex[0]["Equipment Type"], ex[0]["Reps"]) == ("weightLifting", "bodyweight", "60")
    assert (ex[1]["Type"], ex[1]["Distance"], ex[1]["Duration Seconds"]) == ("run", "5.66", "2400")


def test_mood_note_keeps_moments_and_activities_by_name():
    files = build(DAYS)
    note = rows(files, "mood_entries.csv")[1]["Notes"]
    assert note.splitlines() == ["[18:00 · bad] Unproductive (Back Pain)", "Wistful"]
    names = {a["Tag Name"] for a in rows(files, "activity_entries.csv")}
    assert names == {"Study", "Takeout", "Anxiety"}
    tags = {t["Name"]: t["Category"] for t in rows(files, "tags.csv")}
    assert tags["Takeout"] == "Food Source" and tags["Anxiety"] == "Health"
