"""Groups spelling variants of food, exercise and supplement names.

    python -m daylio_migration.canonical          # write proposals
    (review data/migration/aliases.csv, set approve to yes/no)
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
    text = re.sub(r"[^a-z0-9 ]", " ", text)
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
    return all(x == y or (len(x) > 3 and fuzz.ratio(x, y) >= 80) for x, y in zip(ta, tb))


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
        for i, group in enumerate(group_list):
            key_i = spaced_key(group.most_common(1)[0][0])
            if len(key_i) < 5:
                continue
            for j in range(i):
                if j in canon_of:
                    continue
                key_j = spaced_key(group_list[j].most_common(1)[0][0])
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
            top = group_list[root].most_common(1)[0][0]
            canonical = display_name(top)
            for variant, count in group.items():
                if variant == canonical:
                    continue
                if root == i:
                    how, approve = "exact", "yes"
                elif is_likely_same(variant, top):
                    how, approve = "likely typo", "yes"
                else:
                    how, approve = "check", ""
                rows.append({"kind": kind, "canonical": canonical, "variant": variant,
                             "count": count, "how": how, "approve": approve})
    order = {"check": 0, "likely typo": 1, "exact": 2}
    rows.sort(key=lambda r: (r["kind"], order[r["how"]], r["canonical"].lower(), -r["count"]))
    return rows


def load_aliases(path: Path) -> dict[tuple[str, str], str]:
    """(kind, variant) -> canonical for every approved row."""
    if not path.exists():
        return {}
    aliases = {}
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if row.get("approve", "").strip().lower() in ("yes", "y"):
                aliases[(row["kind"], row["variant"])] = row["canonical"]
    return aliases


def apply_aliases(days, aliases: dict[tuple[str, str], str]) -> None:
    """Sets ``canonical`` on every item; the original ``name`` is kept."""
    for day in days:
        for kind in KINDS:
            for item in getattr(day, kind):
                item.canonical = aliases.get((kind, item.name), item.name) if item.name else None


def main() -> None:
    root = Path(__file__).resolve().parents[3] / "data" / "migration"
    days = json.loads((root / "days.json").read_text())
    rows = propose(days)
    out = root / "aliases.csv"
    previous = {}
    if out.exists():  # keep earlier decisions
        with open(out, newline="", encoding="utf-8") as f:
            previous = {(r["kind"], r["variant"]): r["approve"] for r in csv.DictReader(f)}
    for row in rows:
        row["approve"] = previous.get((row["kind"], row["variant"]), row["approve"])
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
