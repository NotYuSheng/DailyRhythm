"""Splits notes written as one run-together string (mostly 2021-2022).

    0700 Reveille Nasi lemak Yong Tau foo 0040 Sleep Dumbbell curl Push ups

The Reveille and Sleep times split the note into a meal part and an
exercise part. Each part is then cut at unambiguous boundaries (prices,
"X2" quantities, rep counts) and the pieces are split into items with a
dictionary of names from the clean, line-per-item notes. Pieces the
dictionary can't fully explain are left for a splitter (the local LLM),
which may only return exact substrings of the piece.
"""

from __future__ import annotations

import re
from typing import Callable

from .lines import AFTER_SLEEP, BEFORE_SLEEP, TIME_ANCHOR, UNKNOWN, _hhmm, classify_item
from .model import Flag, ParsedNote

# Returns the items of `piece` (exact substrings, in order), or None.
Splitter = Callable[[str, str, list[str]], "list[str] | None"]

PRICE_TOKEN = re.compile(r"^[~$]?\d+\.\d{2}$")
QTY_TOKEN = re.compile(r"^[xX]\d+(\.\d+)?$")
COUNT_TOKEN = re.compile(r"^\d+$")
MAX_PHRASE_WORDS = 7


def normalize(text: str) -> str:
    text = text.lower().replace("\xa0", " ")
    text = re.sub(r"[^\w\s&'+/]", " ", text)
    return re.sub(r"\s+", " ", text).strip()


class Lexicon:
    """Item names known from line-per-item notes, keyed by zone."""

    def __init__(self) -> None:
        self.phrases: dict[str, dict[str, int]] = {BEFORE_SLEEP: {}, AFTER_SLEEP: {}}

    def add(self, zone: str, name: str) -> None:
        key = normalize(name)
        if key and len(key.split()) <= MAX_PHRASE_WORDS:
            bucket = self.phrases[zone]
            bucket[key] = bucket.get(key, 0) + 1

    def known(self, zone: str, phrase: str) -> bool:
        """A phrase counts as known if seen at least once as a full line;
        single generic words need to be seen three times."""
        key = normalize(phrase)
        zones = [zone] if zone in self.phrases else list(self.phrases)
        for z in zones:
            count = self.phrases[z].get(key, 0)
            if count >= (3 if len(key.split()) == 1 else 1):
                return True
        return False

    def split(self, zone: str, piece: str) -> list[str] | None:
        """Splits ``piece`` entirely into known phrases, preferring fewer,
        longer phrases. Returns None if any word is left unexplained."""
        words = piece.split()
        n = len(words)
        best: list[tuple[int, list[str]] | None] = [None] * (n + 1)
        best[0] = (0, [])
        for i in range(n):
            if best[i] is None:
                continue
            count, parts = best[i]
            for j in range(i + 1, min(n, i + MAX_PHRASE_WORDS) + 1):
                phrase = " ".join(words[i:j])
                if self.known(zone, phrase):
                    candidate = (count + 1, parts + [phrase])
                    if best[j] is None or candidate[0] < best[j][0]:
                        best[j] = candidate
        return best[n][1] if best[n] else None


def _tokens(text: str) -> list[str]:
    """Whitespace tokens, with a bracketed comment kept as one token."""
    tokens: list[str] = []
    depth = 0
    for word in text.split():
        if depth:
            tokens[-1] += " " + word
        else:
            tokens.append(word)
        depth += word.count("(") + word.count("[") - word.count(")") - word.count("]")
        depth = max(depth, 0)
    return tokens


def _is_comment(token: str) -> bool:
    return token.startswith(("(", "[")) and token.endswith((")", "]"))


def _cut_pieces(text: str, zone: str) -> list[str]:
    """Cuts at boundaries that need no dictionary: after a price or a
    bracketed comment, and before an "X2" quantity or (in the exercise
    part) a rep count. A "+" between two pieces is dropped."""
    pieces: list[list[str]] = [[]]
    tokens = _tokens(text)
    for index, token in enumerate(tokens):
        starts_item = QTY_TOKEN.match(token) or (
            zone == AFTER_SLEEP and COUNT_TOKEN.match(token) and index + 1 < len(tokens)
            and not COUNT_TOKEN.match(tokens[index + 1])
        )
        if starts_item and pieces[-1]:
            pieces.append([])
        pieces[-1].append(token)
        if PRICE_TOKEN.match(token) or _is_comment(token):
            pieces.append([])
    cleaned = []
    for piece in pieces:
        while piece and piece[0] == "+":
            piece = piece[1:]
        while piece and piece[-1] == "+":
            piece = piece[:-1]
        if piece:
            cleaned.append(" ".join(piece))
    return cleaned


def _split_piece(piece: str, zone: str, lexicon: Lexicon, splitter: Splitter | None, note: ParsedNote) -> list[str]:
    # Leading quantity or count belongs to the first item; keep it attached.
    head = ""
    body = piece
    first = piece.split(" ", 1)
    if len(first) == 2 and (QTY_TOKEN.match(first[0]) or COUNT_TOKEN.match(first[0])):
        head, body = first[0] + " ", first[1]
    # A trailing comment and/or price belongs to the last item.
    tail = ""
    tokens = _tokens(body)
    while len(tokens) > 1 and (_is_comment(tokens[-1]) or PRICE_TOKEN.match(tokens[-1])):
        tail = " " + tokens.pop() + tail
    body = " ".join(tokens)

    parts = lexicon.split(zone, body)
    if parts is None and len(body.split()) <= 1:
        parts = [body]
    if parts is None and splitter is not None:
        hints = [p for p in _known_inside(body, zone, lexicon)]
        parts = splitter(body, zone, hints)
        if parts is not None:
            note.flags.append(Flag("llm_split", " | ".join(parts), piece))
    if parts is None:
        note.flags.append(Flag("unsplit", "Could not split into items; kept as one", piece))
        parts = [body]
    parts[0] = head + parts[0]
    parts[-1] = parts[-1] + tail
    return parts


def _known_inside(body: str, zone: str, lexicon: Lexicon) -> list[str]:
    words = body.split()
    found = []
    for i in range(len(words)):
        for j in range(min(len(words), i + MAX_PHRASE_WORDS), i + 1, -1):
            phrase = " ".join(words[i:j])
            if len(phrase.split()) >= 2 and lexicon.known(zone, phrase):
                found.append(phrase)
                break
    return found


def parse_run_together(text: str, lexicon: Lexicon, splitter: Splitter | None = None) -> ParsedNote:
    note = ParsedNote(method="segmented")
    text = re.sub(r"\s+", " ", text.replace("\xa0", " ")).strip()
    anchors = list(TIME_ANCHOR.finditer(text))
    has_bed = any(a["kind"].lower() == "sleep" for a in anchors)

    sections: list[tuple[str, str]] = []
    position = 0
    zone = UNKNOWN if not anchors else (BEFORE_SLEEP if has_bed else UNKNOWN)
    for anchor in anchors:
        if anchor.start() > position:
            sections.append((zone, text[position:anchor.start()]))
        hhmm = _hhmm(anchor["time"])
        if anchor["kind"].lower() == "sleep":
            if note.bed is not None:
                note.flags.append(Flag("duplicate_bed", "More than one bedtime", anchor.group(0)))
            note.bed = note.bed or hhmm
            zone = AFTER_SLEEP
        else:
            if note.wake is not None:
                note.flags.append(Flag("duplicate_wake", "More than one wake time", anchor.group(0)))
            note.wake = note.wake or hhmm
            zone = BEFORE_SLEEP if has_bed else UNKNOWN
        if hhmm is None:
            note.flags.append(Flag("bad_time", "Unreadable time", anchor.group(0)))
        position = anchor.end()
    sections.append((zone, text[position:]))

    for zone, section in sections:
        section = section.strip()
        if not section:
            continue
        for piece in _cut_pieces(section, zone):
            for item in _split_piece(piece, zone, lexicon, splitter, note):
                classify_item(item, zone, note)
    return note


def build_lexicon(notes: list[list[str]]) -> Lexicon:
    """Builds the dictionary from notes already split into lines."""
    from .lines import parse_lines

    lexicon = Lexicon()
    for lines in notes:
        parsed = parse_lines(lines)
        if parsed.bed is None:  # zone unknown, names less trustworthy
            continue
        for meal in parsed.meals:
            lexicon.add(BEFORE_SLEEP, meal.name)
        for supplement in parsed.supplements:
            lexicon.add(BEFORE_SLEEP, supplement.name)
        for exercise in parsed.exercises:
            lexicon.add(AFTER_SLEEP, exercise.name)
    return lexicon
