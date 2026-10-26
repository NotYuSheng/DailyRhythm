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


def display_name(name: str) -> str:
    """Sentence case, keeping acronyms and mixed-case brands (KFC, McChicken)."""
    words = name.strip().split()
    out = []
    for i, w in enumerate(words):
        keep = w.isupper() and len(w) > 1 or any(c.isupper() for c in w[1:])
        if keep:
            out.append(w[0].upper() + w[1:] if i == 0 else w)
        else:
            out.append(w.capitalize() if i == 0 else w.lower())
    return " ".join(out)


def propose(days: list[dict]) -> list[dict]:
    rows = []
    for kind in KINDS:
        counts = Counter(item["name"] for day in days for item in day[kind] if item["name"])

        # 1. exact groups
        groups: dict[str, Counter] = defaultdict(Counter)
        for name, count in counts.items():
            groups[compact_key(name)][name] += count
        group_list = sorted(groups.values(), key=lambda g: -sum(g.values()))

        # 2. fuzzy-merge whole groups into bigger ones
        canon_of: dict[int, int] = {}
        keys = [spaced_key(g.most_common(1)[0][0]) for g in group_list]
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
            own = display_name(group.most_common(1)[0][0])
            for variant, count in group.items():
                if variant != own:
                    rows.append({"kind": kind, "canonical": own, "variant": variant,
                                 "count": count, "how": "exact", "approve": "yes"})
            # A group merged into another is one row, so rejecting the merge
            # keeps the spellings above (aliases chain: variant -> own -> root).
            if root != i:
                top = group_list[root].most_common(1)[0][0]
                how, approve = ("likely typo", "yes") if is_likely_same(own, top) else ("check", "")
                rows.append({"kind": kind, "canonical": display_name(top), "variant": own,
                             "count": sum(group.values()), "how": how, "approve": approve})
    order = {"check": 0, "likely typo": 1, "exact": 2}
    rows.sort(key=lambda r: (r["kind"], order[r["how"]], r["canonical"].lower(), -r["count"]))
    return rows


def load_aliases(path: Path) -> dict[tuple[str, str], str]:
    """(kind, variant) -> canonical for every approved row."""
    if not path.exists():
        return {}
    with open(path, newline="", encoding="utf-8") as f:
        approved = [r for r in csv.DictReader(f) if r.get("approve", "").strip().lower() in ("yes", "y")]
    # Synonyms are added by hand, so they win over generated rows.
    approved.sort(key=lambda r: r["how"] == "synonym")
    return {(r["kind"], r["variant"]): r["canonical"] for r in approved}


def resolve(aliases: dict[tuple[str, str], str], kind: str, name: str) -> str:
    """Follows alias chains, so a spelling variant of a synonym ends at
    the final name (maggie -> Maggie -> Maggi)."""
    seen = set()
    while (kind, name) in aliases and name not in seen:
        seen.add(name)
        name = aliases[(kind, name)]
    return name


def apply_aliases(days, aliases: dict[tuple[str, str], str]) -> None:
    """Sets ``canonical`` on every item; the original ``name`` is kept."""
    for day in days:
        for kind in KINDS:
            for item in getattr(day, kind):
                item.canonical = resolve(aliases, kind, item.name) if item.name else None


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
    rows = merge_previous(propose(days), previous)
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
