"""Groups spelling variants of food, exercise and supplement names.

    python -m daylio_migration.canonical [--out DIR]   # write proposals
    (review data/migration/aliases.csv, set approve to yes/no; add rows with
     how=synonym to rename one agreed name to another, e.g. Maggie -> Maggi)
    python -m daylio_migration ...                # parse again; approved aliases apply

Exact variants (same letters once case, punctuation, spaces and simple
plurals are ignored) are pre-approved. Close spellings found by fuzzy
matching are proposed with approve blank. Names that contain different
numbers are never merged ("6 pc nuggets" vs "9 pc nuggets").
"""

from __future__ import annotations

import csv
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

from rapidfuzz import fuzz

KINDS = ("meals", "exercises", "supplements")
FUZZY_THRESHOLD = 90
FIELDS = ["kind", "canonical", "variant", "count", "how", "approve"]


def spaced_key(name: str) -> str:
    text = name.lower().replace("&", " and ")
    # Letters in any script count ("炒饭", "phở"); only punctuation goes.
    text = re.sub(r"[\W_]", " ", text)
    if not text.strip():
        return name.strip().lower()  # emoji only: keep it, or all would match
    words = []
    for word in text.split():
        if len(word) > 4 and word.endswith(("ches", "shes", "xes")):
            word = word[:-2]  # stretches -> stretch
        elif (len(word) > 3 or word == "ups") and word.endswith("s") and not word.endswith("ss"):
            word = word[:-1]  # crude singular: noodles -> noodle, situps -> situp
        words.append(word)
    return " ".join(words)


def compact_key(name: str) -> str:
    """Ignores spaces too, so 'sit ups' == 'situps' and 'ham string' == 'hamstring'."""
    return spaced_key(name).replace(" ", "")


def _numbers(text: str) -> list[str]:
    return re.findall(r"\d+", text)


CONNECTORS = {"with", "w", "and", "n", "the", "of", "at", "in", "s"}


def is_likely_same(a: str, b: str) -> bool:
    """Same words apart from connectors, each at most slightly misspelled.
    'korean bbq chicken w rice' ~ 'korean bbq chicken with rice': yes.
    'dumpling ban mian' ~ 'dumpling la mian': no (a different word)."""
    ta = [w for w in spaced_key(a).split() if w not in CONNECTORS]
    tb = [w for w in spaced_key(b).split() if w not in CONNECTORS]
    if "".join(ta) == "".join(tb):
        return True  # only spacing differs
    if len(ta) != len(tb):
        return False
    # A different first letter is usually a different word (fried / dried).
    return all(x == y or (len(x) > 3 and x[0] == y[0] and fuzz.ratio(x, y) >= 80) for x, y in zip(ta, tb))


# Names written in lower case that are really acronyms.
ACRONYMS = {"kfc": "KFC", "ktv": "KTV", "bbq": "BBQ", "kbbq": "KBBQ", "mos": "MOS", "a&w": "A&W", "ytf": "YTF"}

# "Fried rice with chicken cutlet and curry veg" is fried rice with sides.
_SIDES = re.compile(r"\s+(?:with|w/|w)\s+|\s*,\s*|\s+\+\s+", re.IGNORECASE)


def base_dish(name: str) -> str:
    """The main dish of a combination: the part before "with", "w/", a
    comma or "+". The full name is kept on the meal; the food it links to
    is the base, so sides don't make every plate a new food."""
    base = _SIDES.split(name.strip(), maxsplit=1)[0].strip()
    return base if len(base) >= 2 else name.strip()


def display_name(name: str) -> str:
    """Sentence case, keeping acronyms and mixed-case brands (KFC, McChicken)."""
    words = name.strip().split()
    out = []
    for i, w in enumerate(words):
        if w.lower() in ACRONYMS:
            out.append(ACRONYMS[w.lower()])
            continue
        keep = w.isupper() and len(w) > 1 or any(c.isupper() for c in w[1:])
        if keep:
            out.append(w[0].upper() + w[1:] if i == 0 else w)
        else:
            out.append(w.capitalize() if i == 0 else w.lower())
    return " ".join(out)


class WordSynonyms:
    """Synonyms applied to whole words inside longer names, ignoring case,
    in one pass with the longest first: Maggie -> Maggi turns "Maggie
    goreng" into "Maggi goreng" but leaves "Maggies" alone, and a rule for
    "maggie mee" wins over one for "mee".

    Only synonyms that keep the word count apply inside names: a respelling
    or a like-for-like rename ("Cai peng" -> "Mixed rice"). One that adds
    words ("chicken" -> "Chicken rice") renames the whole name only, or
    "Chicken burger" would become "Chicken rice burger"."""

    def __init__(self, pairs: list[tuple[str, str]]) -> None:
        self.replacements = {}
        for word, replacement in pairs:
            word = word.strip()
            if word and len(word.split()) == len(replacement.split()):
                self.replacements.setdefault(word.lower(), replacement.strip())
        words = sorted(self.replacements, key=len, reverse=True)
        self.pattern = re.compile(r"(?<!\w)(?:" + "|".join(map(re.escape, words)) + r")(?!\w)", re.IGNORECASE) if words else None

    def apply(self, name: str) -> str:
        if self.pattern is None:
            return name
        return self.pattern.sub(lambda m: self.replacements[m.group(0).lower()], name)


Synonyms = dict[str, WordSynonyms]  # by kind


def propose(days: list[dict], synonyms: Synonyms | None = None) -> list[dict]:
    """Proposes aliases. Names are grouped after word-level [synonyms], so
    "Maggie goreng" joins "Maggi goreng"."""
    rows = []
    for kind in KINDS:
        # Meals are grouped by their base dish (sides don't make a new food).
        key = base_dish if kind == "meals" else (lambda n: n)
        counts = Counter(key(item["name"]) for day in days for item in day[kind] if item["name"])
        rewrite = (synonyms or {}).get(kind, WordSynonyms([])).apply

        # 1. exact groups
        groups: dict[str, Counter] = defaultdict(Counter)
        for name, count in counts.items():
            groups[compact_key(rewrite(name))][name] += count
        group_list = sorted(groups.values(), key=lambda g: -sum(g.values()))

        # 2. fuzzy-merge whole groups into bigger ones
        canon_of: dict[int, int] = {}
        keys = [spaced_key(rewrite(g.most_common(1)[0][0])) for g in group_list]
        for i, key_i in enumerate(keys):
            if len(key_i) < 5:
                continue
            for j in range(i):
                if j in canon_of:
                    continue
                key_j = keys[j]
                if _numbers(key_i) != _numbers(key_j):
                    continue
                score = fuzz.ratio(key_i, key_j)
                if score >= FUZZY_THRESHOLD:
                    canon_of[i] = j
                    break

        for i, group in enumerate(group_list):
            root = i
            while root in canon_of:
                root = canon_of[root]
            # Spellings within a group always fold into its own top name.
            # Rewritten after display_name, so a replacement keeps its case.
            own = rewrite(display_name(group.most_common(1)[0][0]))
            for variant, count in group.items():
                if variant != own:
                    rows.append({"kind": kind, "canonical": own, "variant": variant,
                                 "count": count, "how": "exact", "approve": "yes"})
            # A group merged into another is one row, so rejecting the merge
            # keeps the spellings above (aliases chain: variant -> own -> root).
            if root != i:
                top = rewrite(display_name(group_list[root].most_common(1)[0][0]))
                how, approve = ("likely typo", "yes") if is_likely_same(own, top) else ("check", "")
                rows.append({"kind": kind, "canonical": top, "variant": own,
                             "count": sum(group.values()), "how": how, "approve": approve})
    order = {"check": 0, "likely typo": 1, "exact": 2}
    rows.sort(key=lambda r: (r["kind"], order[r["how"]], r["canonical"].lower(), -r["count"]))
    return rows


def _approved_rows(path: Path) -> list[dict]:
    if not path.exists():
        return []
    with open(path, newline="", encoding="utf-8") as f:
        return [r for r in csv.DictReader(f) if r.get("approve", "").strip().lower() in ("yes", "y")]


def load_aliases(path: Path) -> dict[tuple[str, str], str]:
    """(kind, variant) -> canonical for every approved row."""
    approved = _approved_rows(path)
    # Synonyms are added by hand, so they win over generated rows.
    approved.sort(key=lambda r: r["how"] == "synonym")
    return {(r["kind"], r["variant"]): r["canonical"] for r in approved}


def load_synonyms(path: Path) -> Synonyms:
    """Approved hand-added synonyms by kind, for use inside longer names."""
    pairs: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for r in _approved_rows(path):
        if r["how"] == "synonym":
            pairs[r["kind"]].append((r["variant"], r["canonical"]))
    return {kind: WordSynonyms(p) for kind, p in pairs.items()}


def resolve(aliases: dict[tuple[str, str], str], kind: str, name: str) -> str:
    """Follows alias chains, so a spelling variant of a synonym ends at
    the final name (maggie -> Maggie -> Maggi)."""
    seen = set()
    while (kind, name) in aliases and name not in seen:
        seen.add(name)
        name = aliases[(kind, name)]
    return name


def apply_aliases(days, aliases: dict[tuple[str, str], str], synonyms: Synonyms | None = None) -> int:
    """Sets ``canonical`` on every item; the original ``name`` is kept.
    Whole-name aliases apply first, then synonyms inside longer names.
    Returns how many distinct names the word-level synonyms changed."""
    changed: set[tuple[str, str]] = set()
    for day in days:
        for kind in KINDS:
            words = (synonyms or {}).get(kind)
            for item in getattr(day, kind):
                if not item.name:
                    item.canonical = None
                    continue
                def canonical_of(name: str) -> str:
                    canonical = resolve(aliases, kind, name)
                    rewritten = words.apply(canonical) if words else canonical
                    if rewritten != canonical:
                        # A whole name that is a synonym is a rename, not a change inside it.
                        if canonical.lower() not in words.replacements:
                            changed.add((kind, item.name))
                        canonical = resolve(aliases, kind, rewritten)
                    return canonical

                item.canonical = canonical_of(item.name)
                if kind == "meals":
                    item.food = display_name(canonical_of(base_dish(item.name)))
    return len(changed)


def merge_previous(rows: list[dict], previous: list[dict]) -> list[dict]:
    """Keeps decisions from an earlier aliases.csv. A decision applies only
    to the same proposal: if a variant now points at a different canonical,
    it needs a fresh look. Synonyms are added by hand, so they are kept."""
    decided = {(r["kind"], r["variant"], r["canonical"]): r["approve"] for r in previous}
    for row in rows:
        row["approve"] = decided.get((row["kind"], row["variant"], row["canonical"]), row["approve"])
    return [r for r in previous if r["how"] == "synonym"] + rows


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=Path(__file__).resolve().parents[3] / "data" / "migration",
                        help="the --out folder of the parse, holding days.json")
    root = parser.parse_args().out
    days = json.loads((root / "days.json").read_text())
    out = root / "aliases.csv"
    previous = []
    if out.exists():
        with open(out, newline="", encoding="utf-8") as f:
            previous = list(csv.DictReader(f))
    rows = merge_previous(propose(days, load_synonyms(out)), previous)
    with open(out, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    counts = Counter(r["how"] for r in rows)
    print(f"{counts['exact']} exact and {counts['likely typo']} likely-typo variants pre-approved; "
          f"{counts['check']} to check")
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()
