"""Estimates calories per typical serving for every food in days.json.

    python -m daylio_migration.calories [--out DIR]

Asks the LLM in .env about the foods in batches and writes calories.csv
(food, kcal, serving, count, how). Estimates are for review: change a kcal
to correct it and its row becomes how=user; a corrected or blank row is
kept as it is the next time this runs. app_export then gives each food its
calories (kcal_source "estimate" or "user").
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import urllib.request
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from .llm import load_env

FIELDS = ["food", "kcal", "serving", "count", "how"]
BATCH = 20
MAX_KCAL = 3000


def _prompt(foods: list[str]) -> str:
    listed = "\n".join(f"- {f}" for f in foods)
    return (
        "Estimate the calories in ONE typical serving of each food or drink below, as eaten or bought "
        "in Singapore (a hawker plate, a cafe portion, a fast-food item, one drink, one snack pack). "
        "Names are as a person logged them and may include brands, typos or local words.\n\n"
        f"{listed}\n\n"
        "Answer with only a JSON array, one object per food, in the same order: "
        '[{"food": "<name exactly as given>", "kcal": <whole number>, "serving": "<the serving you assumed>"}]. '
        'Use "kcal": null if it is not food or drink.'
    )


def _extract(content: str) -> list | None:
    match = re.search(r"\[.*\]", content, re.DOTALL)
    if not match:
        return None
    try:
        value = json.loads(match.group(0))
    except json.JSONDecodeError:
        return None
    return value if isinstance(value, list) else None


def _key(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


def accept(foods: list[str], answer: list | None) -> dict[str, dict]:
    """The answers for foods asked about, with a sane whole number. An answer
    names its food (punctuation and spacing aside); when the model tidied
    the name, one answer per food in the same order still lines up."""
    asked = {_key(f): f for f in foods}
    items = [item for item in answer or [] if isinstance(item, dict)]
    in_order = len(items) == len(foods)
    accepted: dict[str, dict] = {}
    for i, item in enumerate(items):
        name = asked.get(_key(str(item.get("food", ""))))
        if name is None and in_order:
            name = foods[i]
        kcal = item.get("kcal")
        if name is None:
            continue
        if kcal is None:
            accepted[name] = {"kcal": None, "serving": ""}
        elif isinstance(kcal, (int, float)) and 0 < kcal <= MAX_KCAL:
            accepted[name] = {"kcal": round(kcal), "serving": str(item.get("serving") or "")[:60]}
    return accepted


class CalorieEstimator:
    def __init__(self, cache_path: Path, base_url: str, api_key: str, model: str, workers: int = 4):
        self.cache_path = cache_path
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.model = model
        self.workers = workers
        self.cache: dict[str, dict] = json.loads(cache_path.read_text()) if cache_path.exists() else {}

    def _ask(self, foods: list[str]) -> dict[str, dict]:
        body = json.dumps({
            "model": self.model,
            "temperature": 0,
            # A list of numbers needs little thought; reasoning models are
            # many times slower without this (servers that don't know it ignore it).
            "reasoning_effort": "low",
            "messages": [{"role": "user", "content": _prompt(foods)}],
        }).encode()
        request = urllib.request.Request(
            f"{self.base_url}/chat/completions",
            data=body,
            headers={"Authorization": f"Bearer {self.api_key}", "Content-Type": "application/json"},
        )
        with urllib.request.urlopen(request, timeout=300) as response:
            content = json.load(response)["choices"][0]["message"]["content"] or ""
        return accept(foods, _extract(content))

    def estimate(self, foods: list[str], progress=print) -> None:
        """Asks about every food not cached yet, in batches; saves as it goes."""
        todo = [f for f in foods if f.lower() not in self.cache]
        batches = [todo[i:i + BATCH] for i in range(0, len(todo), BATCH)]

        def work(batch):
            try:
                return self._ask(batch)
            except Exception as error:  # network or server: asked again next run
                progress(f"  failed batch starting {batch[0]!r}: {error}")
                return {}

        done = 0
        with ThreadPoolExecutor(self.workers) as pool:
            for answers in pool.map(work, batches):
                for name, value in answers.items():
                    self.cache[name.lower()] = value
                done += 1
                if done % 5 == 0 or done == len(batches):
                    progress(f"  {done}/{len(batches)} batches")
                    self.save()
        self.save()

    def save(self) -> None:
        self.cache_path.parent.mkdir(parents=True, exist_ok=True)
        self.cache_path.write_text(json.dumps(self.cache, indent=1, ensure_ascii=False))


def food_counts(days: list[dict]) -> Counter:
    """How often each food (the name app_export links meals to) was eaten."""
    counts: Counter = Counter()
    for day in days:
        for m in day["meals"]:
            if m["name"]:
                counts[m.get("food") or m.get("canonical") or m["name"]] += 1
        for s in day["supplements"]:
            if s["name"]:
                counts[s.get("canonical") or s["name"]] += 1
    return counts


def load_calories(path: Path) -> dict[str, dict]:
    """food (lower case) -> {kcal, how} for rows with a number."""
    if not path.exists():
        return {}
    out = {}
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            try:
                kcal = float(row["kcal"])
            except (TypeError, ValueError):
                continue
            if 0 < kcal <= MAX_KCAL:
                out[row["food"].lower()] = {"kcal": kcal, "how": row.get("how") or "estimate"}
    return out


def write_calories(path: Path, counts: Counter, cache: dict[str, dict]) -> Counter:
    """Writes calories.csv, keeping rows a person changed (how=user) or
    cleared, and taking everything else from the estimates."""
    previous: dict[str, dict] = {}
    if path.exists():
        with open(path, newline="", encoding="utf-8") as f:
            previous = {r["food"].lower(): r for r in csv.DictReader(f)}
    rows, hows = [], Counter()
    for food, count in counts.most_common():
        old = previous.get(food.lower())
        estimate = cache.get(food.lower(), {})
        if old and old.get("how") == "user":
            row = {**old, "count": count}
        elif old and old.get("kcal") not in ("", None) and estimate.get("kcal") is not None and \
                str(old["kcal"]) != str(estimate["kcal"]):
            row = {**old, "count": count, "how": "user"}  # edited since the last run
        else:
            kcal = estimate.get("kcal")
            row = {"food": food, "kcal": "" if kcal is None else kcal, "serving": estimate.get("serving", ""),
                   "count": count, "how": "estimate" if kcal is not None else ("not food" if estimate else "")}
        hows[row["how"] or "unknown"] += 1
        rows.append(row)
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    return hows


def main() -> None:
    root = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=root / "data" / "migration", help="the parse's --out folder")
    parser.add_argument("--no-llm", action="store_true", help="only rewrite calories.csv from earlier answers")
    args = parser.parse_args()

    counts = food_counts(json.loads((args.out / "days.json").read_text()))
    cache_path = args.out / "calories_cache.json"
    if args.no_llm:
        estimator = CalorieEstimator(cache_path, "", "", "")
    else:
        load_env(root / ".env")
        missing = [k for k in ("LLM_BASE_URL", "LLM_API_KEY", "LLM_MODEL") if not os.environ.get(k)]
        if missing:
            raise SystemExit(f"Set {', '.join(missing)} in .env, or pass --no-llm")
        estimator = CalorieEstimator(cache_path, os.environ["LLM_BASE_URL"], os.environ["LLM_API_KEY"], os.environ["LLM_MODEL"])
        print(f"Estimating {sum(1 for f in counts if f.lower() not in estimator.cache)} foods...")
        estimator.estimate(list(counts))
    hows = write_calories(args.out / "calories.csv", counts, estimator.cache)
    print(", ".join(f"{n} {how}" for how, n in hows.most_common()))
    print(f"Wrote {args.out / 'calories.csv'}")


if __name__ == "__main__":
    main()
