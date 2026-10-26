"""Writes parsed days as a DailyRhythm export zip (schema v14).

    python -m daylio_migration.app_export [--days ...] [--garmin ...] [--out ...]

Import the zip with Settings -> Import Data. What maps where:
  - the day's mood becomes the mood entry; each Daylio entry with a note,
    mood or tags becomes a journal moment with its own mood and tags
  - meals and exercises link to their canonical name (food_items,
    exercise_items, with the other spellings as aliases) and keep the
    original line as raw text
  - Daylio meals have no time, so they get placeholder times from 12:00 in
    their original order and are marked time unknown; exercises from 20:00
  - food sources stay day-level tags: Daylio doesn't say which meal they
    were for, so meals get no food source
  - supplements are meals tagged "Supplement"
  - Garmin daily metrics and workouts come from garmin_daily.json, if given
  - every original Daylio entry is kept verbatim in daylio_raw
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import zipfile
from datetime import date, datetime, timedelta
from pathlib import Path

from . import taxonomy
from .canonical import base_dish
from .validate import sleep_hours

# Icon names the app can draw (see journal_screen.dart).
ICONS = {
    "Exercise": "dumbbell", "Nap": "bed", "Woke Up Early": "arrow_up", "Slept Early": "moon",
    "Dentist": "clinic_medical", "Cab": "home", "Homemade": "home",
}
CATEGORIES = {taxonomy.FOOD_SOURCE: "Food Source", taxonomy.ACTIVITY: "Activity", taxonomy.SYMPTOM: "Health"}


def _iso(day: str, hhmm: str | None = None, plus_minutes: int = 0) -> str:
    base = datetime.combine(date.fromisoformat(day), datetime.min.time())
    if hhmm:
        h, m = map(int, hhmm.split(":"))
        base = base.replace(hour=h, minute=m)
    return (base + timedelta(minutes=plus_minutes)).isoformat(timespec="milliseconds")


def _sleep_hours(bed: str, wake: str) -> float:
    return round(sleep_hours(bed, wake), 2)


def _csv(rows: list[list]) -> str:
    out = io.StringIO()
    csv.writer(out, lineterminator="\r\n").writerows(rows)
    return out.getvalue()


KINDS = {taxonomy.FOOD_SOURCE: "food_source", taxonomy.ACTIVITY: "activity", taxonomy.SYMPTOM: "symptom"}
KIND_BY_NAME = {name: kind for kind, name in taxonomy.ACTIVITIES.values()}


def _catalog(names: list[tuple[str, str]]) -> dict[str, list[str]]:
    """canonical -> other spellings, from (canonical, as written) pairs."""
    items: dict[str, dict[str, str]] = {}
    for canonical, written in names:
        spellings = items.setdefault(canonical, {})
        if written.lower() != canonical.lower():
            spellings.setdefault(written.lower(), written)
    return {name: sorted(spellings.values(), key=str.lower) for name, spellings in items.items()}


def build(days: list[dict], garmin: list[dict] | None = None) -> dict[str, str]:
    by_date = {d["date"]: d for d in days}
    sleep = [["ID", "Date", "Wake Up Time", "Sleep Time", "Total Hours", "Nap Hours", "Tags"]]
    meals = [["ID", "Date", "Time", "Name", "Quantity", "Price", "Calories", "Tags", "Notes",
              "Food Source", "Food Item", "Currency", "Raw Text", "Time Known"]]
    moods = [["ID", "Date", "Timestamp", "Mood Level", "Emoji", "Notes"]]
    exercises = [[
        "ID", "Date", "Timestamp", "Type", "Run Type", "Distance", "Duration Seconds", "Pace Seconds",
        "Interval Distance Seconds", "Interval Time Seconds", "Rest Time Seconds", "Interval Count",
        "Exercise Name", "Equipment Type", "Reps", "Weight", "Sets", "Notes", "Exercise Item", "Raw Text",
    ]]
    activities = [["ID", "Date", "Timestamp", "Tag ID", "Notes", "Tag Name", "Severity"]]
    journal = [["ID", "Date", "Time", "Text", "Mood", "Source", "Created At", "Tag Names"]]
    raw = [["Date", "Logged Time", "Mood", "Activities", "Note"]]
    spending = [["ID", "Date", "Time", "Label", "Amount", "Currency", "Category", "Notes", "Raw Text"]]
    used_tags: dict[str, str] = {}  # name -> category
    food_names: list[tuple[str, str]] = []
    exercise_names: list[tuple[str, str]] = []
    cardio: set[str] = set()
    last_price: dict[str, float] = {}

    for d in days:  # in date order, so the last price seen is the latest
        day = d["date"]
        midnight = _iso(day)

        if d["wake"] or d["bed"]:
            previous = by_date.get((date.fromisoformat(day) - timedelta(days=1)).isoformat())
            total = _sleep_hours(previous["bed"], d["wake"]) if previous and previous["bed"] and d["wake"] else ""
            sleep.append(["", midnight, _iso(day, d["wake"]) if d["wake"] else "",
                          _iso(day, d["bed"]) if d["bed"] else "", total, "", ""])

        meal_rows = [(m, []) for m in d["meals"]] + [
            ({"text": s.get("text", s["name"]), "name": s["name"], "canonical": s.get("canonical"),
              "quantity": s["quantity"], "price": None, "currency": "SGD", "comment": None,
              "price_approx": False}, ["Supplement"])
            for s in d["supplements"]]
        for i, (m, tags) in enumerate(meal_rows):
            if not m["name"]:
                continue
            name = m.get("canonical") or m["name"]
            # Paid-for group events and gifts aren't meals: their own file.
            if kind := m.get("spending"):
                spending.append(["", midnight, _iso(day, "19:00", i), name, m["price"], m["currency"], kind,
                                 m.get("comment") or "", m.get("text") or ""])
                continue
            food = m.get("food") or name
            food_names.append((food, base_dish(m["name"])))
            notes = []
            quantity = m["quantity"] or 1
            if quantity != int(quantity):  # the app stores whole quantities
                notes.append(f"quantity {quantity:g}")
            if m.get("comment"):
                notes.append(m["comment"])
            if m.get("price_approx"):
                notes.append("approximate price")
            price = m["price"]
            # A plate with sides costs more than the dish alone.
            # The app remembers what one entry cost, so only single orders count.
            if price is not None and m["currency"] == "SGD" and food.lower() == name.lower() and quantity == 1:
                last_price[food] = round(price, 2)
            meals.append(["", midnight, _iso(day, "12:00", i), name, max(1, round(quantity)),
                          "" if price is None else price, "", ";".join(tags), "; ".join(notes),
                          "", food, m["currency"], m.get("text") or "", 0])

        if d["mood"] is not None:
            moods.append(["", midnight, _iso(day, "23:59"), d["mood"], "", ""])

        for j in d["journal"]:
            for tag in j["tags"]:
                used_tags.setdefault(tag, CATEGORIES[KIND_BY_NAME.get(tag, taxonomy.ACTIVITY)])
            # After midnight it was the next calendar day, so it sorts last.
            at = _iso(day, j["time"], 24 * 60 if j.get("next_day") else 0) if j["time"] else ""
            journal.append(["", midnight, at, j["text"], "" if j["mood"] is None else j["mood"], "daylio",
                            at or midnight, ";".join(j["tags"])])

        for i, x in enumerate(d["exercises"]):
            # A line that was only a distance or a duration ("5km", "30 mins").
            name = x.get("canonical") or x["name"] or ("Run" if x["distance_km"] is not None else "Workout")
            exercise_names.append((name, x["name"] or name))
            is_cardio = x["distance_km"] is not None
            if is_cardio:
                cardio.add(name)
            # What the columns don't hold: cardio has a duration column, and
            # weight always has its own.
            extra = ("steps",) if is_cardio else ("duration_min", "steps")
            notes = "; ".join(f"{k} {x[k]:g}" for k in extra if x[k] is not None)
            exercises.append([
                "", midnight, _iso(day, "20:00", i),
                "run" if is_cardio else "weightLifting", "flat" if is_cardio else "",
                x["distance_km"] if is_cardio else "",
                int(x["duration_min"] * 60) if is_cardio and x["duration_min"] else "",
                "", "", "", "", "", name, "" if is_cardio else "bodyweight",
                x["reps"] if x["reps"] is not None else "", x["weight_kg"] if x["weight_kg"] is not None else "",
                x["sets"] if x["sets"] is not None else "", notes, name, x.get("text") or "",
            ])

        for kind, names in ((taxonomy.ACTIVITY, d["activities"]), (taxonomy.FOOD_SOURCE, d["food_sources"]),
                            (taxonomy.SYMPTOM, d["symptoms"])):
            for name in names:
                used_tags.setdefault(name, CATEGORIES[kind])
                activities.append(["", midnight, _iso(day, "23:59"), "", "", name, ""])

        for e in d["entries"]:
            raw.append([midnight, e["time"], "" if e["mood"] is None else e["mood"], " | ".join(e["activities"]), e["note"]])

    used_tags.setdefault("Supplement", "Food Source")
    tags = [["ID", "Name", "Emoji", "Category", "Color", "Sort Order", "Kind"]] + [
        ["", name, ICONS.get(name, "glass_martini" if cat == "Food Source" else "exclamation_triangle"), cat, "", "",
         "food_source" if name == "Supplement" else KINDS[KIND_BY_NAME.get(name, taxonomy.ACTIVITY)]]
        for name, cat in sorted(used_tags.items())
    ]
    categories = [["ID", "Name", "Color", "Sort Order"]] + [
        ["", name, "", ""] for name in sorted(set(used_tags.values()))
    ]
    foods = [["ID", "Name", "Aliases", "Kcal", "Kcal Source", "Last Price"]] + [
        ["", name, ";".join(aliases), "", "", last_price.get(name, "")]
        for name, aliases in sorted(_catalog(food_names).items(), key=lambda kv: kv[0].lower())
    ]
    exercise_items = [["ID", "Name", "Aliases", "Category"]] + [
        ["", name, ";".join(aliases), "cardio" if name in cardio else "strength"]
        for name, aliases in sorted(_catalog(exercise_names).items(), key=lambda kv: kv[0].lower())
    ]

    metrics = [["Date", "Metric", "Value", "Source"]]
    workouts = [["Start", "Type", "Duration Min", "Distance Km", "Kcal", "Avg HR", "Max HR", "Source"]]
    for g in garmin or []:
        for metric, value in sorted(g["metrics"].items()):
            metrics.append([_iso(g["date"]), metric, value, g["source"]])
        for w in g["workouts"]:
            workouts.append([datetime.fromisoformat(w["start"]).isoformat(timespec="milliseconds"), w["type"] or "other",
                             *("" if w[k] is None else w[k] for k in ("duration_min", "distance_km", "kcal", "avg_hr", "max_hr")),
                             g["source"]])

    files = {
        "sleep_entries.csv": sleep, "meal_entries.csv": meals, "mood_entries.csv": moods,
        "exercise_entries.csv": exercises, "activity_entries.csv": activities, "tags.csv": tags,
        "tag_categories.csv": categories, "food_items.csv": foods, "exercise_items.csv": exercise_items,
        "journal_entries.csv": journal, "daylio_raw.csv": raw, "spending_entries.csv": spending,
        "health_metrics.csv": metrics, "health_workouts.csv": workouts,
    }
    return {name: _csv(rows) for name, rows in files.items() if len(rows) > 1}


def main() -> None:
    root = Path(__file__).resolve().parents[3] / "data" / "migration"
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--days", type=Path, default=root / "days.json")
    parser.add_argument("--garmin", type=Path, default=root / "garmin_daily.json",
                        help="output of daylio_migration.garmin; skipped if missing")
    parser.add_argument("--out", type=Path, default=root / "dailyrhythm_import.zip")
    args = parser.parse_args()

    garmin = json.loads(args.garmin.read_text()) if args.garmin.exists() else None
    files = build(json.loads(args.days.read_text()), garmin)
    with zipfile.ZipFile(args.out, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, content in files.items():
            archive.writestr(name, content)
    for name, content in files.items():
        print(f"  {name}: {content.count(chr(13) + chr(10)) - 1} rows")
    print(f"Wrote {args.out}")


if __name__ == "__main__":
    main()
