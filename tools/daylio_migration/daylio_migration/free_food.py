"""Marks meals that cost nothing but weren't labelled as such.

Daylio's "Free Food" tag is on the day, not the meal. A meal counts as free
(price 0, noted) when it has no price and:

- comes from a camp or work canteen that is never paid for (SAFTI, NSC,
  HVC, SMEAC, cookhouse, catering, NDP), or is a buffet, bento or banquet;
- is the only unpriced meal on a day tagged Free Food; or
- is listed in free_meals.csv (date,name) next to days.json: meals the
  person confirmed, kept out of the code as they name people and places.
"""

from __future__ import annotations

import csv
import re
from pathlib import Path

from .model import Day, Meal

CANTEEN = re.compile(r"^(?:safti|nsc|hvc|smeac|catering|catered|ndp)\b", re.IGNORECASE)
COOKHOUSE = re.compile(r"^cookhouse\b", re.IGNORECASE)
EVENT = re.compile(r"\b(?:buffet|bento|banquet)\b", re.IGNORECASE)
SUPPLEMENT = re.compile(r"\b(?:creatine|protein|vitamins?|fish oil)\b", re.IGNORECASE)
LABELLED = ("free", "rations", "CDC voucher")


def load_confirmed(path: Path) -> set[tuple[str, str]]:
    """(date, name lower) pairs from free_meals.csv, if there is one."""
    if not path.exists():
        return set()
    with open(path, newline="", encoding="utf-8") as f:
        return {(r["date"].strip(), r["name"].strip().lower()) for r in csv.DictReader(f)}


def _labelled(m: Meal) -> bool:
    return any(word in (m.comment or "") for word in LABELLED)


def _mark(m: Meal, note: str) -> None:
    m.price = 0.0
    m.comment = "; ".join(c for c in (m.comment, note) if c)


def mark_free(days: list[Day], confirmed: set[tuple[str, str]] = frozenset()) -> int:
    """Marks free meals in place; returns how many."""
    marked = 0
    for day in days:
        unpriced = [m for m in day.meals if m.price is None and not m.spending and not SUPPLEMENT.search(m.name)]
        chosen: list[tuple[Meal, str]] = []
        for m in unpriced:
            if (day.date, m.name.lower()) in confirmed or (day.date, (m.canonical or "").lower()) in confirmed:
                chosen.append((m, "free"))
            elif COOKHOUSE.search(m.name):
                chosen.append((m, "rations"))
            elif CANTEEN.search(m.name) or EVENT.search(m.name):
                chosen.append((m, "free"))
        if not chosen and "Free Food" in day.food_sources and len(unpriced) == 1 and not any(_labelled(m) for m in day.meals):
            chosen.append((unpriced[0], "free"))
        for m, note in chosen:
            _mark(m, note)
            marked += 1
    return marked
