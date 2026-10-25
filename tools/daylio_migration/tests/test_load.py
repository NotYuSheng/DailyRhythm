from daylio_migration.load import build_days
from daylio_migration.model import DaylioEntry


def entry(date, time, mood, note, activities=()):
    return DaylioEntry(date=date, time=time, mood=mood, activities=list(activities), note=note)


def test_date_is_the_day_described():
    # Logged after midnight but the previous day has its own entry: keep the date.
    days = build_days([
        entry("2022-03-30", "20:00", 3, "0800 Reveille<br>Mixed rice<br>0130 Sleep"),
        entry("2022-03-31", "02:13", 3, "0900 Reveille<br>Udon<br>0220 Sleep"),
    ])
    assert [d.date for d in days] == ["2022-03-30", "2022-03-31"]


def test_late_log_with_unchanged_date_moves_to_previous_day():
    days = build_days([entry("2026-10-25", "03:04", 3, "0800 Reveille<br>Wanton noodles 3.50<br>0310 Sleep")])
    assert days[0].date == "2026-10-24"
    assert [f.code for f in days[0].flags] == ["logical_day_shift"]


def test_activities_are_split_by_category():
    day = build_days([entry("2024-01-01", "23:59", 3, "", ["takeout", "gaming", "anxiety", "studying"])])[0]
    assert day.food_sources == ["Takeout"]
    assert day.activities == ["Video Games", "Study"]
    assert day.symptoms == ["Anxiety"]


def test_multi_entry_day_keeps_each_moment():
    day = build_days([
        entry("2024-12-24", "23:59", 3, "0800 Reveille<br>Stuffs ~8<br>0100 Sleep", ["exercise", "homemade"]),
        entry("2024-12-24", "18:00", 2, "Unproductive", ["backpain", "drowzee"]),
    ])[0]
    # Day mood comes from the last entry (the end-of-day summary)
    assert day.mood == 3
    moment = next(j for j in day.journal if j.text == "Unproductive")
    assert (moment.mood, moment.tags) == (2, ["Back Pain", "Drowsiness"])
    assert "multi_entry_day" in {f.code for f in day.flags}


def test_single_entry_journal_has_no_separate_mood():
    day = build_days([entry("2024-01-01", "23:59", 2, "0700 Reveille<br>0100 Sleep<br>Tired after the exam")])[0]
    assert day.mood == 2
    assert [(j.text, j.mood) for j in day.journal] == [("Tired after the exam", None)]
