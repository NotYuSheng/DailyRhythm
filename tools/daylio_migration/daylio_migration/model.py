"""Structured records produced from a Daylio export.

Every record keeps the exact source text it was parsed from (``text``) so a
parse can always be checked against, or redone from, the original note.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field


@dataclass
class Meal:
    text: str
    name: str
    canonical: str | None = None  # agreed spelling, from aliases.csv
    quantity: float | None = None
    price: float | None = None
    currency: str = "SGD"  # USD/MYR when the note says so
    price_approx: bool = False  # written as "~10"
    comment: str | None = None  # parenthetical remark


@dataclass
class ExerciseSet:
    text: str
    name: str
    canonical: str | None = None
    reps: int | None = None
    sets: int | None = None
    weight_kg: float | None = None
    duration_min: float | None = None
    distance_km: float | None = None
    steps: int | None = None


@dataclass
class Supplement:
    text: str
    name: str
    canonical: str | None = None
    quantity: float | None = None


@dataclass
class JournalEntry:
    """Free text about the day, optionally with its own mood and tags."""

    text: str
    mood: int | None = None
    time: str | None = None  # HH:MM the Daylio entry was logged
    tags: list[str] = field(default_factory=list)


@dataclass
class Flag:
    """Something the parser was unsure about; listed in the review CSV."""

    code: str
    detail: str
    text: str | None = None


@dataclass
class DaylioEntry:
    """One row of the Daylio CSV, unchanged apart from parsing the mood."""

    date: str  # YYYY-MM-DD as exported
    time: str  # HH:MM (24h) as exported
    mood: int | None
    activities: list[str]
    note: str  # raw note, HTML entities decoded


@dataclass
class ParsedNote:
    wake: str | None = None  # HH:MM
    bed: str | None = None  # HH:MM; times before noon mean after midnight
    timezone: str | None = None
    meals: list[Meal] = field(default_factory=list)
    exercises: list[ExerciseSet] = field(default_factory=list)
    supplements: list[Supplement] = field(default_factory=list)
    journal: list[str] = field(default_factory=list)
    flags: list[Flag] = field(default_factory=list)
    method: str = "empty"  # empty | lines | segmented


@dataclass
class Day:
    """Everything known about one logical day (wake to sleep)."""

    date: str
    mood: int | None
    entries: list[DaylioEntry]
    wake: str | None = None
    bed: str | None = None
    timezone: str | None = None
    activities: list[str] = field(default_factory=list)
    food_sources: list[str] = field(default_factory=list)
    symptoms: list[str] = field(default_factory=list)
    meals: list[Meal] = field(default_factory=list)
    exercises: list[ExerciseSet] = field(default_factory=list)
    supplements: list[Supplement] = field(default_factory=list)
    journal: list[JournalEntry] = field(default_factory=list)
    flags: list[Flag] = field(default_factory=list)
    method: str = "empty"

    def to_dict(self) -> dict:
        return asdict(self)
