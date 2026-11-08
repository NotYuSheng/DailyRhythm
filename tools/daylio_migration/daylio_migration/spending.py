"""Lines that are really group events or gifts, not meals."""

from __future__ import annotations

import re

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
