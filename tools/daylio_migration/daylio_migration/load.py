"""Reads the Daylio CSV and groups entries into days.

An entry's date is the day it describes; its time is only when it was
logged. The one exception: an entry logged after midnight whose note
shows that night hadn't ended (e.g. logged 03:04, "0310 Sleep") when the
previous day has no entry at all. That is a day logged late without
changing the date, so it moves to the previous day (and is flagged).
"""

from __future__ import annotations

import csv
import html
from collections import defaultdict
from datetime import date, datetime, timedelta
from pathlib import Path

from . import taxonomy
from .lines import parse_lines
from .model import DaylioEntry, Day, Flag, JournalEntry, ParsedNote
from .segment import Lexicon, Splitter, build_lexicon, parse_run_together

BR = "<br>"


def _minutes(hhmm: str | None) -> int | None:
    if hhmm is None:
        return None
    h, m = hhmm.split(":")
    return int(h) * 60 + int(m)


def read_entries(path: Path) -> list[DaylioEntry]:
    entries = []
    with open(path, encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            logged = datetime.strptime(row["time"].strip(), "%I:%M %p").strftime("%H:%M")
            mood_name = row["mood"].strip().lower()
            mood = taxonomy.MOODS.get(mood_name)
            entries.append(DaylioEntry(
                date=row["full_date"],
                time=logged,
                mood=mood,
                unknown_mood=mood_name if mood is None and mood_name else None,
                activities=[a.strip() for a in row["activities"].split("|") if a.strip()],
                note=html.unescape(row["note"]).strip(),
            ))
    return entries


def note_lines(note: str) -> list[str] | None:
    """The note's lines if it uses <br> separators, else None."""
    if BR not in note:
        return None
    return [line.strip() for line in note.split(BR) if line.strip()]


def parse_note(note: str, lexicon: Lexicon, splitter: Splitter | None = None) -> ParsedNote:
    if not note:
        return ParsedNote()
    lines = note_lines(note)
    if lines is not None:
        return parse_lines(lines)
    return parse_run_together(note, lexicon, splitter)


def logical_date(entry: DaylioEntry, parsed: ParsedNote, dated: set[str]) -> tuple[str, bool]:
    """Returns (date, shifted). ``dated`` is every date that has an entry."""
    logged = _minutes(entry.time)
    if logged >= 12 * 60:
        return entry.date, False
    previous = (date.fromisoformat(entry.date) - timedelta(days=1)).isoformat()
    if previous in dated:
        return entry.date, False
    wake = _minutes(parsed.wake)
    bed = _minutes(parsed.bed)
    woke_after_logging = wake is not None and wake > logged
    not_yet_asleep = bed is not None and bed < 12 * 60 and bed >= logged
    if woke_after_logging or not_yet_asleep:
        return previous, True
    return entry.date, False


def _order_key(entry: DaylioEntry, shifted: bool) -> int:
    """Minutes since the logical day started; after-midnight logs sort last."""
    minutes = _minutes(entry.time)
    return minutes + (24 * 60 if shifted else 0)


def build_days(entries: list[DaylioEntry], splitter: Splitter | None = None) -> list[Day]:
    lexicon = build_lexicon([lines for e in entries if (lines := note_lines(e.note))])

    dated = {e.date for e in entries}
    grouped: dict[str, list[tuple[DaylioEntry, ParsedNote, bool]]] = defaultdict(list)
    for entry in entries:
        parsed = parse_note(entry.note, lexicon, splitter)
        day, shifted = logical_date(entry, parsed, dated)
        grouped[day].append((entry, parsed, shifted))

    days = []
    for day_date in sorted(grouped):
        items = sorted(grouped[day_date], key=lambda t: _order_key(t[0], t[2]))
        days.append(_merge_day(day_date, items))
    return days


def _merge_day(day_date: str, items: list[tuple[DaylioEntry, ParsedNote, bool]]) -> Day:
    # The last entry of the day is the end-of-day summary; it sets the mood.
    summary_entry = items[-1][0]
    day = Day(date=day_date, mood=summary_entry.mood, entries=[e for e, _, _ in items])

    if len(items) > 1:
        moods = ", ".join(f"{e.time} {e.mood}" for e, _, _ in items)
        day.flags.append(Flag("multi_entry_day", f"{len(items)} entries ({moods}); day mood from the last"))

    methods = {p.method for _, p, _ in items if p.method != "empty"}
    day.method = "+".join(sorted(methods)) or "empty"

    for entry, parsed, shifted in items:
        if shifted:
            day.flags.append(Flag("logical_day_shift", f"Logged {entry.date} {entry.time}; moved to the previous day"))
        if entry.unknown_mood:
            day.flags.append(Flag("unknown_mood", f"Custom mood '{entry.unknown_mood}'; add it to taxonomy.MOODS"))
        for tag in entry.activities:
            category = taxonomy.categorize(tag)
            if category is None:
                day.flags.append(Flag("unknown_activity", tag))
                continue
            kind, name = category
            target = {taxonomy.FOOD_SOURCE: day.food_sources, taxonomy.SYMPTOM: day.symptoms}.get(kind, day.activities)
            if name not in target:
                target.append(name)

        for field, value in (("wake", parsed.wake), ("bed", parsed.bed), ("timezone", parsed.timezone)):
            if value is None:
                continue
            current = getattr(day, field)
            if current is not None and current != value:
                day.flags.append(Flag(f"conflicting_{field}", f"{current} vs {value}; kept {current}"))
            elif current is None:
                setattr(day, field, value)

        day.meals += parsed.meals
        day.exercises += parsed.exercises
        day.supplements += parsed.supplements
        day.flags += parsed.flags

        # Other entries keep their own mood and activities as journal tags.
        is_summary = entry is summary_entry
        text = "\n".join(parsed.journal)
        if text or (len(items) > 1 and not is_summary):
            tags = [] if (is_summary and len(items) == 1) else [
                c[1] for t in entry.activities if (c := taxonomy.categorize(t))
            ]
            day.journal.append(JournalEntry(
                text=text,
                mood=None if (is_summary and len(items) == 1) else entry.mood,
                time=entry.time,
                tags=tags,
                next_day=shifted,
            ))
    return day
