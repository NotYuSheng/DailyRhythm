"""Builds assets/data/usda_foods.json from USDA FoodData Central SR Legacy.

    curl -LO https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip
    unzip FoodData_Central_sr_legacy_food_csv_2018-04.zip -d usda
    python3 tool/usda/build_usda_foods.py usda/FoodData_Central_sr_legacy_food_csv_2018-04

SR Legacy is public domain (CC0 1.0). Each food keeps its description, kcal
per 100 g (nutrient 1008) and up to two common portions in grams. Baby
foods and the American Indian/Alaska Native category are left out.
"""
import collections
import csv
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'assets', 'data', 'usda_foods.json')
SKIP = {'Baby Foods', 'American Indian/Alaska Native Foods'}


def rows(src, name):
    with open(os.path.join(src, name), newline='', encoding='utf-8') as f:
        yield from csv.DictReader(f)


def main(src):
    cats = {r['id']: r['description'] for r in rows(src, 'food_category.csv')}
    units = {r['id']: r['name'] for r in rows(src, 'measure_unit.csv')}
    foods = {r['fdc_id']: r['description'].strip() for r in rows(src, 'food.csv') if cats.get(r['food_category_id']) not in SKIP}
    kcal = {}
    for r in rows(src, 'food_nutrient.csv'):
        if r['nutrient_id'] == '1008' and r['fdc_id'] in foods:
            try:
                kcal[r['fdc_id']] = float(r['amount'])
            except ValueError:
                pass
    portions = collections.defaultdict(list)
    for r in rows(src, 'food_portion.csv'):
        if r['fdc_id'] not in kcal:
            continue
        try:
            grams = float(r['gram_weight'])
        except ValueError:
            continue
        if not 5 <= grams <= 1000:
            continue
        amount = r['amount'].strip()
        try:
            amount = f'{float(amount):g}'
        except ValueError:
            pass
        desc = (r['modifier'] or r['portion_description'] or units.get(r['measure_unit_id'], '')).strip()
        if not desc or desc.lower() in ('undetermined', 'quantity not specified'):
            continue
        label = f'{amount} {desc}' if amount and amount != '1' else desc
        if amount == '1' and not re.match(r'^(1|one)\b', desc):
            label = f'1 {desc}'
        portions[r['fdc_id']].append((int(r['seq_num'] or 99), label, round(grams, 1)))
    entries = []
    for fid, name in foods.items():
        if fid not in kcal:
            continue
        entry = {'n': name, 'k': round(kcal[fid])}
        top = [[label, grams] for _, label, grams in sorted(portions[fid])[:2]]
        if top:
            entry['p'] = top
        entries.append(entry)
    entries.sort(key=lambda e: e['n'].lower())
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump(entries, f, separators=(',', ':'), ensure_ascii=False)
    print(f'{len(entries)} foods -> {OUT}')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    main(sys.argv[1])
