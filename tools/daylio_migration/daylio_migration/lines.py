"""Parses the one-item-per-line note format.

A note is a sequence of items in a fairly fixed order:

    0700 Reveille            wake time (HHMM)
    Wanton noodles 3.50      meals, price at the end (optional)
    X2 protein               supplements
    0150 Sleep               bedtime; before noon means after midnight
    60 situps                exercises, reps first (optional)
    Wistful, unsettled       free text about the day

Lines before the Sleep line are meals or supplements and lines after it are
exercises or free text, which resolves most ambiguous lines. Notes with no
Sleep line fall back to keyword rules and are flagged for review.
"""

from __future__ import annotations

import re

from .model import ExerciseSet, Flag, Meal, ParsedNote, Supplement

BEFORE_SLEEP = "before"  # meal zone
AFTER_SLEEP = "after"  # exercise / free-text zone
UNKNOWN = "unknown"  # note has no Sleep line

# Accepts the typos seen in the export ("Reveill", "eveille", "Revellie").
TIME_LINE = re.compile(
    r"^(?P<time>\d{3,6})\s*(?:(?P<tz>[A-Z]{3,4})\s+)?(?P<kind>r?evei?ll?(?:ie|e)?|revellie|woke(?: up)?|wake(?: up)?|sleep)\b"
    r"[.:]?\s*(?P<rest>.*)$",
    re.IGNORECASE,
)
# Tokens matched anywhere, for notes written as one run-together string.
TIME_ANCHOR = re.compile(
    r"\b(?P<time>\d{3,6})\s*(?:(?P<tz>[A-Z]{3,4})\s+)?(?P<kind>r?evei?ll?(?:ie|e)?|revellie|sleep)\b",
    re.IGNORECASE,
)
TIMEZONES = {
    "SGT", "PDT", "PST", "EDT", "EST", "CDT", "CST", "MDT", "MST", "JST", "KST",
    "HKT", "MYT", "ICT", "WIB", "CET", "CEST", "BST", "GMT", "UTC", "AEST", "AEDT",
}

PAREN = re.compile(r"\s*[\(\[](?P<comment>[^\)\]]*)[\)\]]\s*")
CURRENCY_WORDS = {"usd": "USD", "us$": "USD", "ringgit": "MYR", "myr": "MYR", "rm": "MYR", "sgd": "SGD"}
# "... 3.50", "... $7", "... ~10", "... 22 usd", "... $130 ringgit"
PRICE_END = re.compile(
    r"(?:^|\s)(?P<approx>~)?\$?(?P<price>\d+(?:\.\d{1,2})?)\s*(?P<cur>usd|ringgit|myr|rm|sgd)?\s*$",
    re.IGNORECASE,
)
# "... USD 11.60"
CURRENCY_FIRST_END = re.compile(r"\s(?P<cur>usd|us\$|rm|myr|sgd)\s*\$?(?P<price>\d+(?:\.\d{1,2})?)\s*$", re.IGNORECASE)
QUANTITY_PREFIX = re.compile(r"^[xX]\s?(?P<qty>\d+(?:\.\d+)?)\s*(?P<rest>.+)$")
COUNT_PREFIX = re.compile(r"^(?P<count>\d+)\s+(?P<rest>[^\d\s].*)$")
# Names that start with a number but aren't a count.
NUMBERED_NAMES = re.compile(r"^(7\s?-?\s?eleven|7-11|7\s?up|4\s?fingers|1\s?for\s?1)\b", re.IGNORECASE)
# "2 plain 1 egg prata", "X2 plain X1 egg": several counted parts of one order
COMPOUND = re.compile(r"^(?:[xX]?\d+(?:\.\d+)?\s+[^\d]+?\s*){2,}$")
COMPOUND_PART = re.compile(r"[xX]?(?P<qty>\d+(?:\.\d+)?)\s+(?P<name>[^\d]+?)(?=\s+[xX]?\d|\s*$)")

SETS_X_REPS = re.compile(r"\b(?P<sets>\d+)\s*sets?\s*(?:x|of)\s*(?P<reps>\d+)\b", re.IGNORECASE)
SETS_ONLY = re.compile(r"\b(?P<sets>\d+)\s*sets?\b", re.IGNORECASE)
WEIGHT = re.compile(r"\b(?P<kg>\d+(?:\.\d+)?)\s*kgs?\b", re.IGNORECASE)
DISTANCE = re.compile(r"\b(?P<km>\d+(?:\.\d+)?)\s*km\b", re.IGNORECASE)
DURATION = re.compile(r"\b(?P<min>\d+(?:\.\d+)?)\s*(?:mins?|minutes?)\b", re.IGNORECASE)
STEPS = re.compile(r"\b(?P<steps>\d+(?:\.\d+)?)\s*(?P<k>k)?\s*steps\b", re.IGNORECASE)

EXERCISE_WORDS = re.compile(
    r"\b(curls?|press(es)?|squats?|push ?-?ups?|pushups?|sit ?-?ups?|situps?|crunch(es)?|planks?|"
    r"raises?|rows?|dips?|pull ?-?ups?|pullups?|chin ?-?ups?|jumping jacks?|burpees?|lunges?|deadlifts?|"
    r"bridges?|stretch(es|ing)?|twists?|jog(ging)?|run(ning)?|cycl(e|ing)|swim(ming)?|walk(ing)?|"
    r"hike|hiking|flys?|flyes?|extensions?|kickbacks?|shrugs?|mountain climbers?|leg raises?|"
    r"bicep|tricep|dumbbells?|kettlebell|barbell|gym|yoga|skipping|hamstrings?|abs|cardio|steps)\b",
    re.IGNORECASE,
)
SUPPLEMENT_WORDS = re.compile(
    r"^(protein( shake| bar)?|creatine|multivitamins?|vitamins? ?\w?|fish oil|omega ?3|magnesium|zinc|"
    r"electrolytes?|pre ?-?workout|whey)$",
    re.IGNORECASE,
)
FEELING_WORDS = re.compile(
    r"\b(feel(ing|s)?|felt|tired|exhausted|sad|happy|anxious|wistful|unsettled|stressed|stress|bored|"
    r"lonely|productive|unproductive|rested|energetic|lethargic|overwhelmed|frustrated|annoyed|angry|"
    r"motivated|unmotivated|depressed|calm|content|grateful|regret|worried|nervous|mood|decisions?|"
    r"pain|aches?|sick|diarrh\w*|fever|vomit\w*|headache|nause\w*|hell|travell?ing|"
    r"results?|planning|resolved|quiz|exam|meeting|roadshow)\b",
    re.IGNORECASE,
)
# Used only when a note has no Sleep line to tell meals from remarks.
FOOD_WORDS = re.compile(
    r"\b(rice|noodles?|soup|chicken|egg|eggs|bread|burger|pizza|prata|coffee|tea|juice|milo|mee|hoon|"
    r"kway|teow|gyoza|porridge|sandwich|nasi|lemak|wrap|nuggets?|fries|croissant|cake|pasta|spaghetti|fish|"
    r"pork|beef|duck|mutton|tofu|curry|laksa|dumplings?|bao|bun|muffin|mcmuffin|mc\w+|kfc|subway|"
    r"food|meal|set|bento|salad|fruit|apple|banana|orange|biscuits?|chips|cereal|oat\w*|yoghurt|"
    r"ice cream|chocolate|snack|drink|kopi|teh|onigiri|sushi|ramen|udon|don|katsu|cai peng|bbq|buffet|"
    r"hotpot|steak|nachos|express|rations|cookhouse)\b",
    re.IGNORECASE,
)


def _hhmm(raw: str) -> str | None:
    """'0150' -> '01:50'. Six digits (HHMMSS) keep the first four."""
    digits = raw[:4].zfill(4)
    hours, minutes = int(digits[:2]), int(digits[2:])
    if hours > 23 or minutes > 59:
        return None
    return f"{hours:02d}:{minutes:02d}"


def parse_time_line(line: str) -> tuple[str, str | None, str | None, str] | None:
    """Returns (kind, HH:MM, timezone, rest of line) for a wake/sleep line."""
    match = TIME_LINE.match(line.strip())
    if not match:
        return None
    kind = "bed" if match["kind"].lower() == "sleep" else "wake"
    rest = match["rest"].strip()
    timezone = match["tz"]  # "0200 UST Sleep"
    first = rest.split(" ", 1)[0]
    if timezone is None and first.upper() in TIMEZONES and first.isupper():
        timezone = first
        rest = rest[len(first):].strip()
    return kind, _hhmm(match["time"]), timezone, rest


def _clean(text: str) -> str:
    return re.sub(r"\s+", " ", text.replace("\xa0", " ")).strip(" .,-")


def parse_meal(line: str, flags: list[Flag]) -> Meal:
    text = line.strip()
    body = text
    comments = [m["comment"].strip() for m in PAREN.finditer(body)]
    body = PAREN.sub(" ", body).strip()

    price = None
    approx = False
    currency = "SGD"
    match = CURRENCY_FIRST_END.search(body) or PRICE_END.search(body)
    if match and not NUMBERED_NAMES.fullmatch(body.strip()):
        candidate = float(match["price"])
        rest = body[: match.start()].strip()
        if rest:  # a bare number is not a priced meal
            price = candidate
            approx = bool(match.groupdict().get("approx"))
            if match["cur"]:
                currency = CURRENCY_WORDS[match["cur"].lower()]
            body = rest

    quantity = None
    if COMPOUND.match(body) and not NUMBERED_NAMES.match(body):
        # One order of several kinds: total count, parts kept as a comment.
        parts = [(float(m["qty"]), _clean(m["name"])) for m in COMPOUND_PART.finditer(body)]
        quantity = sum(q for q, _ in parts)
        comments.append(", ".join(f"{q:g} {n}" for q, n in parts))
        body = " ".join(n for _, n in parts)
    elif q := QUANTITY_PREFIX.match(body):
        quantity = float(q["qty"])
        body = q["rest"]
    elif not NUMBERED_NAMES.match(body):
        c = COUNT_PREFIX.match(body)
        if c and int(c["count"]) <= 20:
            quantity = float(c["count"])
            body = c["rest"]

    meal = Meal(
        text=text,
        name=_clean(body),
        quantity=quantity,
        price=price,
        currency=currency,
        price_approx=approx,
        comment="; ".join(comments) or None,
    )
    if currency != "SGD":
        flags.append(Flag("foreign_currency", f"Price in {currency}", text))
    if price is not None and price > 30 and currency == "SGD":
        flags.append(Flag("price_high", f"${price:.2f} for one item", text))
    return meal


def parse_exercise(line: str) -> ExerciseSet:
    text = line.strip()
    body = PAREN.sub(" ", text).strip()
    ex = ExerciseSet(text=text, name="")

    if m := SETS_X_REPS.search(body):
        ex.sets, ex.reps = int(m["sets"]), int(m["reps"])
        body = body[: m.start()] + body[m.end():]
    elif m := SETS_ONLY.search(body):
        ex.sets = int(m["sets"])
        body = body[: m.start()] + body[m.end():]
    if m := WEIGHT.search(body):
        ex.weight_kg = float(m["kg"])
        body = body[: m.start()] + body[m.end():]
    if m := DISTANCE.search(body):
        ex.distance_km = float(m["km"])
        body = body[: m.start()] + body[m.end():]
    if m := DURATION.search(body):
        ex.duration_min = float(m["min"])
        body = body[: m.start()] + body[m.end():]
    if m := STEPS.search(body):
        steps = float(m["steps"]) * (1000 if m["k"] else 1)
        ex.steps = int(steps)
        body = body[: m.start()] + "steps" + body[m.end():]

    body = _clean(body)
    q = QUANTITY_PREFIX.match(body) or COUNT_PREFIX.match(body)
    if q:
        count = q.groupdict().get("qty") or q.groupdict().get("count")
        count = float(count)
        if ex.sets is None and re.match(r"^sets?\b", q["rest"], re.IGNORECASE):
            ex.sets = int(count)
            body = re.sub(r"^sets?\s*", "", q["rest"], flags=re.IGNORECASE)
        elif ex.reps is None:
            ex.reps = int(count)
            body = q["rest"]
    # "x10" left inside the name means reps
    if ex.reps is None and (m := re.search(r"\bx\s?(?P<reps>\d+)\b", body, re.IGNORECASE)):
        ex.reps = int(m["reps"])
        body = body[: m.start()] + body[m.end():]
    ex.name = _clean(body).strip(", ")
    return ex


def parse_supplement(line: str) -> Supplement:
    text = line.strip()
    q = QUANTITY_PREFIX.match(text)
    if q:
        return Supplement(text=text, name=_clean(q["rest"]), quantity=float(q["qty"]))
    return Supplement(text=text, name=_clean(text))


def _strip_quantity(line: str) -> str:
    q = QUANTITY_PREFIX.match(line.strip())
    return q["rest"] if q else line.strip()


def is_supplement(line: str) -> bool:
    return bool(SUPPLEMENT_WORDS.match(_clean(_strip_quantity(line))))


def is_exercise(line: str) -> bool:
    """Short line naming a movement, or with distance/steps/duration."""
    stripped = _strip_quantity(PAREN.sub(" ", line))
    if DISTANCE.search(stripped) or STEPS.search(stripped):
        return True
    if FEELING_WORDS.search(stripped):
        return False
    words = stripped.split()
    return bool(EXERCISE_WORDS.search(stripped)) and len(words) <= 8


def is_feeling(line: str) -> bool:
    return bool(FEELING_WORDS.search(line)) or ("," in line and len(line.split()) >= 4 and not PRICE_END.search(line))


def classify_item(line: str, zone: str, note: ParsedNote) -> None:
    """Adds one non-time item to ``note`` based on its text and zone."""
    line = line.strip()
    if not line:
        return
    if is_supplement(line):
        note.supplements.append(parse_supplement(line))
        return

    priced = bool(re.search(r"\d+\.\d{2}\s*(usd|ringgit|myr|rm)?\s*(\(.*\))?\s*$", line, re.IGNORECASE))
    if zone == BEFORE_SLEEP:
        if not priced and is_exercise(line):  # a few workouts are logged before Sleep
            note.exercises.append(parse_exercise(line))
        elif not priced and is_feeling(line):
            note.journal.append(line)
        else:
            note.meals.append(parse_meal(line, note.flags))
        return

    if zone == AFTER_SLEEP:
        if priced:
            note.meals.append(parse_meal(line, note.flags))
            note.flags.append(Flag("meal_after_sleep", "Priced line after the Sleep line", line))
        elif is_exercise(line) or COUNT_PREFIX.match(line) or QUANTITY_PREFIX.match(line):
            note.exercises.append(parse_exercise(line))
        else:
            note.journal.append(line)
        return

    # No Sleep line: decide from the text alone.
    if priced or (PRICE_END.search(line) and FOOD_WORDS.search(line)):
        note.meals.append(parse_meal(line, note.flags))
    elif is_exercise(line):
        note.exercises.append(parse_exercise(line))
    elif is_feeling(line):
        note.journal.append(line)
    elif FOOD_WORDS.search(line):
        note.meals.append(parse_meal(line, note.flags))
        note.flags.append(Flag("guessed_meal", "No Sleep line; looks like food", line))
    else:
        note.journal.append(line)
        note.flags.append(Flag("guessed_journal", "No Sleep line; assumed a remark", line))


def parse_lines(lines: list[str]) -> ParsedNote:
    """Parses a note that is already split into one item per line."""
    note = ParsedNote(method="lines")
    lines = [l.strip() for l in lines if l.strip()]
    has_bed = any((t := parse_time_line(l)) and t[0] == "bed" for l in lines)
    zone = BEFORE_SLEEP if has_bed else UNKNOWN

    for line in lines:
        timed = parse_time_line(line)
        if timed:
            kind, hhmm, timezone, rest = timed
            if hhmm is None:
                note.flags.append(Flag("bad_time", "Unreadable time", line))
            elif kind == "wake":
                if note.wake is not None:
                    note.flags.append(Flag("duplicate_wake", "More than one wake time", line))
                note.wake = note.wake or hhmm
            else:
                if note.bed is not None:
                    note.flags.append(Flag("duplicate_bed", "More than one bedtime", line))
                note.bed = note.bed or hhmm
            if timezone:
                note.timezone = timezone
                note.flags.append(Flag("timezone", f"Time recorded in {timezone}", line))
            if kind == "bed":
                zone = AFTER_SLEEP
            if rest:  # "0630 Reveille Burger king 5.50"
                classify_item(rest, zone if kind == "bed" else (BEFORE_SLEEP if has_bed else UNKNOWN), note)
            continue
        classify_item(line, zone, note)
    return note
