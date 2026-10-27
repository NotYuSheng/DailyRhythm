"""Builds the app's built-in table of common foods and their calories.

    python -m daylio_migration.common_foods

Asks the LLM in .env for typical-serving calories of common foods, one
group at a time, and writes assets/data/common_foods.json. The groups are
generic (no one's logs are sent). Each group is saved as it finishes, so a
stopped run continues where it left off. The values are estimates; the app
labels them so and anything the user types replaces them.
"""

from __future__ import annotations

import json
import os
import re
import urllib.request
from pathlib import Path

from .llm import load_env

GROUPS = [
    "Singapore hawker rice dishes: chicken rice, duck rice, nasi lemak, briyani, claypot rice, char siew rice, mixed rice plates",
    "Singapore mixed rice (cai fan / cai peng) plates by number of dishes, and economy bee hoon or noodles with sides",
    "Singapore hawker noodles, part 1: laksa, wanton mee, char kway teow, hokkien mee, mee goreng, bak chor mee",
    "Singapore hawker noodles, part 2: fishball noodles, ban mian, mee hoon kueh, lor mee, prawn noodles, kway teow soup",
    "Singapore hawker dishes: yong tau foo, carrot cake (white and black), oyster omelette, satay, popiah, rojak",
    "Roti prata, murtabak, thosai, chapati, naan, and other Indian dishes eaten in Singapore",
    "Malay dishes: nasi padang plate, mee rebus, mee siam, lontong, ayam penyet, nasi goreng, mee soto",
    "Soups and one-bowl meals: fish soup, bak kut teh, sliced fish bee hoon, thunder tea rice, porridge, mala xiang guo",
    "Kopitiam breakfast: kaya toast set, half-boiled eggs, curry puff, chee cheong fun, pau, kueh, you tiao",
    "Dim sum items: har gow, siew mai, char siew bao, lo mai gai, egg tart, carrot cake, dumplings",
    "Kopitiam drinks per cup: kopi, kopi-o, kopi-c, teh, teh-o, milo, horlicks, barley, lime juice, sugarcane",
    "Bubble tea and other cold drinks: milk tea with pearls, fruit tea, soya milk, coconut, bottled tea, soft drinks",
    "McDonald's Singapore menu items: burgers, McSpicy, Filet-O-Fish, nuggets, fries, McMuffins, desserts",
    "KFC, Texas Chicken, Jollibee, Popeyes: chicken pieces, burgers, wraps, sides, meals",
    "Burger King, Mos Burger, Subway, Long John Silver's: named menu items and meals",
    "Japanese: ramen, udon, donburi, katsu curry, sushi plate, onigiri, bento, karaage",
    "Korean and Chinese restaurant: bibimbap, Korean fried chicken, tteokbokki, fried rice, dumplings, hotpot portion",
    "Western cafe and food court: pasta, chicken chop, fish and chips, burger, steak, pizza slice, salad, wrap, sandwich",
    "Packaged snacks and sweets: chips, chocolate bars, biscuits, Maggi and cup noodles, granola bars, ice cream, cake slice",
    "Bakery: croissant, bread rolls, buns, sausage bread, doughnut, muffin, cookies, tarts",
    "Fruit and simple foods: banana, apple, orange, durian, rice bowl, bread slice, egg, oats, yoghurt, milk, nuts",
    "Gym and supplements: protein shake, protein bar, creatine, electrolyte drink, energy gel",
    "Army and canteen meals in Singapore: cookhouse meal, field rations, canteen set meals",
    "Convenience store food: 7-Eleven onigiri, sandwiches, hot dog bun, microwave meals, siew mai, tea eggs",
]


def _prompt(group: str) -> str:
    return (
        f"List 20 to 30 common foods or drinks in this group, as eaten in Singapore: {group}. "
        "For each give the calories in ONE typical serving, the usual everyday name, and up to 3 other "
        "common names or spellings. Answer with only a JSON array: "
        '[{"name": "...", "aliases": ["..."], "kcal": <whole number>}]'
    )


def _ask(group: str, base_url: str, api_key: str, model: str) -> list[dict]:
    # Low reasoning: many times faster on reasoning models, ignored elsewhere.
    body = json.dumps({"model": model, "temperature": 0, "reasoning_effort": "low",
                       "messages": [{"role": "user", "content": _prompt(group)}]}).encode()
    request = urllib.request.Request(
        f"{base_url.rstrip('/')}/chat/completions",
        data=body,
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=900) as response:
        content = json.load(response)["choices"][0]["message"]["content"] or ""
    match = re.search(r"\[.*\]", content, re.DOTALL)
    return json.loads(match.group(0)) if match else []


def clean(items: list) -> list[dict]:
    """Well-formed entries with a believable number, names de-duplicated."""
    out, seen = [], set()
    for item in items:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name", "")).strip()
        try:
            kcal = round(float(item.get("kcal")))
        except (TypeError, ValueError):
            continue
        if not name or name.lower() in seen or not 0 < kcal <= 3000:
            continue
        seen.add(name.lower())
        aliases = [str(a).strip() for a in item.get("aliases") or [] if str(a).strip() and str(a).strip().lower() != name.lower()]
        out.append({"name": name, "aliases": aliases[:3], "kcal": kcal})
    return out


def main() -> None:
    root = Path(__file__).resolve().parents[3]
    load_env(root / ".env")
    missing = [k for k in ("LLM_BASE_URL", "LLM_API_KEY", "LLM_MODEL") if not os.environ.get(k)]
    if missing:
        raise SystemExit(f"Set {', '.join(missing)} in .env")
    partial = root / "data" / "common_foods_partial.json"  # data/ is private and ignored
    done: dict[str, list] = json.loads(partial.read_text()) if partial.exists() else {}
    for i, group in enumerate(GROUPS, 1):
        if group in done:
            continue
        for attempt in range(3):
            try:
                done[group] = _ask(group, os.environ["LLM_BASE_URL"], os.environ["LLM_API_KEY"], os.environ["LLM_MODEL"])
                break
            except Exception as error:  # timeouts on a busy local model
                print(f"  group {i}: attempt {attempt + 1} failed: {error}")
        partial.parent.mkdir(parents=True, exist_ok=True)
        partial.write_text(json.dumps(done, ensure_ascii=False))
        print(f"  {i}/{len(GROUPS)} groups")
    table = clean([item for group in GROUPS for item in done.get(group, [])])
    out = root / "assets" / "data" / "common_foods.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(table, indent=1, ensure_ascii=False) + "\n")
    print(f"Wrote {len(table)} foods to {out}")


if __name__ == "__main__":
    main()
