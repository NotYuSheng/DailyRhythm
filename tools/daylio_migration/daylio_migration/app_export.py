"""Writes parsed days as a DailyRhythm export zip (current app schema).

    python -m daylio_migration.app_export --out data/migration/dailyrhythm_import.zip

Import the zip with Settings -> Import Data. This is a preview for the
current schema, which can't hold everything yet, so some detail is folded:
  - food sources (day level in Daylio) become activity tags for the day
  - journal moments and the day's remarks go into the mood note
  - meals have no time in Daylio, so they get placeholder times from 12:00
    in their original order; exercises likewise from 20:00
  - supplements are meals tagged "Supplement"
The full import comes with the extended schema; the raw notes stay in
days.json either way.
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

# Icon names the app can draw (see journal_screen.dart).
ICONS = {
    "Exercise": "dumbbell", "Nap": "bed", "Woke Up Early": "arrow_up", "Slept Early": "moon",
    "Dentist": "clinic_medical", "Cab": "home", "Homemade": "home",
}
CATEGORIES = {taxonomy.FOOD_SOURCE: "Food Source", taxonomy.ACTIVITY: "Activity", taxonomy.SYMPTOM: "Health"}
MOOD_WORDS = {1: "awful", 2: "bad", 3: "meh", 4: "good", 5: "rad"}


def _iso(day: str, hhmm: str | None = None, plus_minutes: int = 0) -> str:
    base = datetime.combine(date.fromisoformat(day), datetime.min.time())
    if hhmm:
        h, m = map(int, hhmm.split(":"))
        base = base.replace(hour=h, minute=m)
    return (base + timedelta(minutes=plus_minutes)).isoformat(timespec="milliseconds")


def _sleep_hours(bed: str, wake: str) -> float:
    to_min = lambda t: int(t[:2]) * 60 + int(t[3:])
    return round(((to_min(wake) - to_min(bed)) % 1440) / 60, 2)


def _csv(rows: list[list]) -> str:
    out = io.StringIO()
    csv.writer(out, lineterminator="\r\n").writerows(rows)
    return out.getvalue()


def build(days: list[dict]) -> dict[str, str]:
    by_date = {d["date"]: d for d in days}
    sleep = [["ID", "Date", "Wake Up Time", "Sleep Time", "Total Hours", "Nap Hours", "Tags"]]
    meals = [["ID", "Date", "Time", "Name", "Quantity", "Price", "Calories", "Tags", "Notes"]]
    moods = [["ID", "Date", "Timestamp", "Mood Level", "Emoji", "Notes"]]
    exercises = [[
        "ID", "Date", "Timestamp", "Type", "Run Type", "Distance", "Duration Seconds", "Pace Seconds",
        "Interval Distance Seconds", "Interval Time Seconds", "Rest Time Seconds", "Interval Count",
        "Exercise Name", "Equipment Type", "Reps", "Weight", "Sets", "Notes",
    ]]
    activities = [["ID", "Date", "Timestamp", "Tag ID", "Notes", "Tag Name"]]
    used_tags: dict[str, str] = {}  # name -> category

    for d in days:
        day = d["date"]
        midnight = _iso(day)

        if d["wake"] or d["bed"]:
            previous = by_date.get((date.fromisoformat(day) - timedelta(days=1)).isoformat())
            total = _sleep_hours(previous["bed"], d["wake"]) if previous and previous["bed"] and d["wake"] else ""
            sleep.append(["", midnight, _iso(day, d["wake"]) if d["wake"] else "",
                          _iso(day, d["bed"]) if d["bed"] else "", total, "", ""])

        meal_rows = [(m, []) for m in d["meals"]] + [
            ({"name": s.get("canonical") or s["name"], "quantity": s["quantity"], "price": None, "currency": "SGD",
              "comment": None, "price_approx": False}, ["Supplement"]) for s in d["supplements"]]
        for i, (m, tags) in enumerate(meal_rows):
            if not m["name"]:
                continue
            notes = []
            quantity = m["quantity"] or 1
            if quantity != int(quantity):  # the app stores whole quantities
                notes.append(f"quantity {quantity:g}")
            if m.get("comment"):
                notes.append(m["comment"])
            price = m["price"]
            if price is not None and m["currency"] != "SGD":
                notes.append(f"{price:g} {m['currency']}")
                price = None
            elif m.get("price_approx"):
                notes.append("approximate price")
            meals.append(["", midnight, _iso(day, "12:00", i), m.get("canonical") or m["name"], max(1, round(quantity)),
                          "" if price is None else price, "", ";".join(tags), "; ".join(notes)])

        if d["mood"] is not None:
            lines = []
            for j in d["journal"]:
                if j["mood"] is None and not j["tags"]:
                    lines.append(j["text"])
                else:
                    meta = " · ".join(x for x in (j["time"], MOOD_WORDS.get(j["mood"])) if x)
                    tags = f" ({', '.join(j['tags'])})" if j["tags"] else ""
                    lines.append(f"[{meta}] {j['text']}{tags}".strip())
            moods.append(["", midnight, _iso(day, "23:59"), d["mood"], "", "\n".join(lines)])

        for i, x in enumerate(d["exercises"]):
            if not x["name"]:
                continue
            is_cardio = x["distance_km"] is not None
            notes = "; ".join(f"{k} {x[k]:g}" for k in ("duration_min", "steps", "weight_kg") if x[k] is not None and not is_cardio)
            exercises.append([
                "", midnight, _iso(day, "20:00", i),
                "run" if is_cardio else "weightLifting", "flat" if is_cardio else "",
                x["distance_km"] if is_cardio else "",
                int(x["duration_min"] * 60) if is_cardio and x["duration_min"] else "",
                "", "", "", "", "", x.get("canonical") or x["name"], "" if is_cardio else "bodyweight",
                x["reps"] if x["reps"] is not None else "", x["weight_kg"] if x["weight_kg"] is not None else "",
                x["sets"] if x["sets"] is not None else "", notes,
            ])

        for kind, names in ((taxonomy.ACTIVITY, d["activities"]), (taxonomy.FOOD_SOURCE, d["food_sources"]),
                            (taxonomy.SYMPTOM, d["symptoms"])):
            for name in names:
                used_tags.setdefault(name, CATEGORIES[kind])
                activities.append(["", midnight, _iso(day, "23:59"), "", "", name])

    used_tags.setdefault("Supplement", "Food Source")
    tags = [["ID", "Name", "Emoji", "Category", "Color", "Sort Order"]] + [
        ["", name, ICONS.get(name, "glass_martini" if cat == "Food Source" else "exclamation_triangle"), cat, "", ""]
        for name, cat in sorted(used_tags.items())
    ]
    categories = [["ID", "Name", "Color", "Sort Order"]] + [
        ["", name, "", ""] for name in sorted(set(used_tags.values()))
    ]
    return {
        "sleep_entries.csv": _csv(sleep), "meal_entries.csv": _csv(meals), "mood_entries.csv": _csv(moods),
        "exercise_entries.csv": _csv(exercises), "activity_entries.csv": _csv(activities),
        "tags.csv": _csv(tags), "tag_categories.csv": _csv(categories),
    }


def main() -> None:
    root = Path(__file__).resolve().parents[3] / "data" / "migration"
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--days", type=Path, default=root / "days.json")
    parser.add_argument("--out", type=Path, default=root / "dailyrhythm_import.zip")
    args = parser.parse_args()

    files = build(json.loads(args.days.read_text()))
    with zipfile.ZipFile(args.out, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, content in files.items():
            archive.writestr(name, content)
    for name, content in files.items():
        print(f"  {name}: {content.count(chr(13) + chr(10)) - 1} rows")
    print(f"Wrote {args.out}")


if __name__ == "__main__":
    main()
