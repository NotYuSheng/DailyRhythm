"""Parses a Daylio export into structured days plus a review file.

    python -m daylio_migration data/daylio_export.csv --out data/migration [--llm]

Writes:
    days.json     one record per logical day, raw notes included
    review.csv    every flagged item, with a blank column for corrections
    summary.txt   counts by method and flag
"""

from __future__ import annotations

import argparse
import csv
import json
from collections import Counter
from pathlib import Path

from .canonical import apply_aliases, load_aliases
from .llm import LlmSplitter, load_env
from .load import build_days, read_entries
from .validate import validate

REPO_ROOT = Path(__file__).resolve().parents[3]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("export", type=Path)
    parser.add_argument("--out", type=Path, default=REPO_ROOT / "data" / "migration")
    parser.add_argument("--llm", action="store_true", help="ask the LLM in .env about pieces not in the cache yet")
    parser.add_argument("--no-cache", action="store_true", help="ignore earlier LLM answers: rules only")
    args = parser.parse_args()

    entries = read_entries(args.export)
    cache = args.out / "llm_cache.json"
    splitter = None
    if args.llm:
        load_env(REPO_ROOT / ".env")
        splitter = LlmSplitter.from_env(cache)
        build_days(entries, splitter)  # first pass queues unknown pieces
        if splitter.pending:
            print(f"Asking the LLM about {len(splitter.pending)} pieces...")
            splitter.run_pending()
    elif cache.exists() and not args.no_cache:
        splitter = LlmSplitter.cache_only(cache)  # reuse earlier answers, ask nothing
        print(f"Using earlier LLM answers from {cache} (--no-cache for rules only)")

    days = build_days(entries, splitter)
    apply_aliases(days, load_aliases(args.out / "aliases.csv"))
    validate(days)
    write_outputs(days, args.out)


def write_outputs(days, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    (out / "days.json").write_text(json.dumps([d.to_dict() for d in days], indent=1, ensure_ascii=False))

    with open(out / "review.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["date", "flag", "detail", "text", "correction"])
        for day in days:
            for flag in day.flags:
                writer.writerow([day.date, flag.code, flag.detail, flag.text or "", ""])

    flags = Counter(flag.code for day in days for flag in day.flags)
    methods = Counter(day.method for day in days)
    totals = {
        "days": len(days),
        "entries": sum(len(d.entries) for d in days),
        "meals": sum(len(d.meals) for d in days),
        "priced meals": sum(1 for d in days for m in d.meals if m.price is not None),
        "exercises": sum(len(d.exercises) for d in days),
        "supplements": sum(len(d.supplements) for d in days),
        "journal entries": sum(len(d.journal) for d in days),
        "days with wake and bed": sum(1 for d in days if d.wake and d.bed),
    }
    lines = [f"{k}: {v}" for k, v in totals.items()]
    lines += ["", "Parse method:"] + [f"  {k}: {v}" for k, v in methods.most_common()]
    lines += ["", "Flags:"] + [f"  {k}: {v}" for k, v in flags.most_common()]
    (out / "summary.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    print(f"\nWrote {out}/days.json, review.csv, summary.txt")


if __name__ == "__main__":
    main()
