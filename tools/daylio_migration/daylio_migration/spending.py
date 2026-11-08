"""Lines that are really group events or gifts, not meals."""

from __future__ import annotations

import csv
import re
from pathlib import Path

from .model import Day

GIFT_WORDS = re.compile(r"\b(wedding|ang ?bao|hong ?bao)\b", re.IGNORECASE)
EVENT_WORDS = re.compile(
    r"\b(farewell|welcom\w*|celebrat\w*|party|ktv|karaoke|rally|d&d|dinner and dance|reunion|hackathon|"
    r"send ?off)\b",
    re.IGNORECASE,
)
# An event word on a cheap line is usually food ("Party wings 9", "KTV sushi
# 12"); the events seen in real notes cost $50 and up.
MIN_EVENT_PRICE = 40


def spending_kind(name: str, price: float | None) -> str | None:
    """'gift' or 'event' for a priced line that is really one, else None."""
    if price is None:
        return None
    if GIFT_WORDS.search(name):
        return "gift"
    if price >= MIN_EVENT_PRICE and EVENT_WORDS.search(name):
        return "event"
    return None


def load_events(path: Path) -> set[tuple[str, str]]:
    """(date, name lower) pairs from events.csv: priced lines the user says
    were group events. Kept out of the repo, like free_meals.csv."""
    if not path.exists():
        return set()
    with open(path, newline="", encoding="utf-8") as f:
        return {(r["date"].strip(), r["name"].strip().lower()) for r in csv.DictReader(f)}


def mark_events(days: list[Day], confirmed: set[tuple[str, str]]) -> int:
    """Marks the confirmed lines as events; returns how many."""
    marked = 0
    for day in days:
        for m in day.meals:
            if m.spending is None and m.price is not None and (day.date, m.name.lower()) in confirmed:
                m.spending = "event"
                marked += 1
    return marked
