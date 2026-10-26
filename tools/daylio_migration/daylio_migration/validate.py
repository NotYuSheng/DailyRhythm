"""Checks that need more than one note: sleep length and daily spend."""

from __future__ import annotations

from datetime import date, timedelta

from .model import Day, Flag

MIN_SLEEP_HOURS = 3
MAX_SLEEP_HOURS = 13
MAX_DAY_SPEND = 60  # SGD


def _minutes(hhmm: str) -> int:
    h, m = hhmm.split(":")
    return int(h) * 60 + int(m)


def sleep_hours(bed: str, wake: str) -> float:
    """Clock-time duration; same rule as the app (bed before noon = after midnight)."""
    return ((_minutes(wake) - _minutes(bed)) % (24 * 60)) / 60


def _hhmm(minutes: int) -> str:
    return f"{minutes // 60 % 24:02d}:{minutes % 60:02d}"


def fix_evening_bedtimes(days: list[Day]) -> None:
    """Some notes (mostly 2022) give bedtimes in 12-hour form: "1115 Sleep"
    meaning 23:15. Read as morning, the next night looks 20+ hours long.
    A bedtime from 08:00 to 12:59 becomes evening when that is the only
    reading that gives a believable night before the next day's wake."""
    by_date = {d.date: d for d in days}
    for day in days:
        if day.bed is None or not 8 * 60 <= _minutes(day.bed) < 13 * 60:
            continue
        following = by_date.get((date.fromisoformat(day.date) + timedelta(days=1)).isoformat())
        if not following or not following.wake:
            continue
        evening = _hhmm(_minutes(day.bed) + 12 * 60)
        as_written = sleep_hours(day.bed, following.wake)
        as_evening = sleep_hours(evening, following.wake)
        if as_written > MAX_SLEEP_HOURS and MIN_SLEEP_HOURS <= as_evening <= MAX_SLEEP_HOURS:
            day.flags.append(Flag("bed_pm", f"Bedtime {day.bed} read as {evening}"))
            day.bed = evening


def validate(days: list[Day]) -> None:
    fix_evening_bedtimes(days)
    by_date = {d.date: d for d in days}
    for day in days:
        has_note = any(e.note for e in day.entries)
        if has_note and day.wake is None:
            day.flags.append(Flag("missing_wake", "No wake time in the note"))
        if has_note and day.bed is None:
            day.flags.append(Flag("missing_bed", "No bedtime in the note"))

        if day.bed is not None and 10 * 60 <= _minutes(day.bed) < 19 * 60:
            day.flags.append(Flag("daytime_bed", f"Bedtime {day.bed} (kept: may be a night shift)"))

        previous = by_date.get((date.fromisoformat(day.date) - timedelta(days=1)).isoformat())
        if previous and previous.bed and day.wake:
            hours = sleep_hours(previous.bed, day.wake)
            if not MIN_SLEEP_HOURS <= hours <= MAX_SLEEP_HOURS:
                day.flags.append(Flag("sleep_length", f"{hours:.1f}h from {previous.bed} to {day.wake}"))

        spend = sum(m.price for m in day.meals if m.price is not None and m.currency == "SGD" and not m.spending)
        if spend > MAX_DAY_SPEND:
            day.flags.append(Flag("day_spend_high", f"${spend:.2f} in one day"))
