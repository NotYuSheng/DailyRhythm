# Daylio migration

One-time conversion of a Daylio CSV export into structured DailyRhythm data.
Personal data stays in `data/` (gitignored); this folder holds only code.

## Setup

```bash
python3 -m venv .venv            # from the repo root; .venv is gitignored
.venv/bin/pip install -r tools/daylio_migration/requirements.txt
```

## Run

```bash
cd tools/daylio_migration
../../.venv/bin/python -m daylio_migration ../../data/daylio_export.csv          # rules + dictionary only
../../.venv/bin/python -m daylio_migration ../../data/daylio_export.csv --llm    # also split leftovers with the LLM
../../.venv/bin/python -m pytest
```

`--llm` reads `LLM_BASE_URL`, `LLM_API_KEY` and `LLM_MODEL` from the repo's `.env`
(any OpenAI-compatible server). Only pieces of run-together notes the dictionary
can't split are sent, and an answer is used only if its items are exact substrings
that rebuild the piece. Answers are cached in `data/migration/llm_cache.json`.
Later runs without `--llm` reuse those answers; pass `--no-cache` for rules only.

Output in `data/migration/`:

| File | Contents |
|---|---|
| `days.json` | One record per day: mood, wake/bed, meals, exercises, supplements, journal entries, activities by category, the raw Daylio entries, and flags |
| `review.csv` | Every flagged item with a blank `correction` column |
| `summary.txt` | Counts by parse method and flag |

Read from the same folder if present: `aliases.csv` (agreed spellings) and
`free_meals.csv` (`date,name`: meals you confirm were free, kept out of the repo
as they name people and places).

**Free meals.** Meals paid with CDC vouchers, free ones and army rations cost
nothing of your own: the parser takes "cdc", "$10 cdc voucher", "free" and
"ration" out of the name, notes them, and sets the price to 0 (a voucher's value
stays in the note). Unlabelled meals count as free when they have no price and come
from a canteen that's never paid for (SAFTI, NSC, HVC, cookhouse, catering), are a
buffet, bento or banquet, or are the only unpriced meal on a day tagged Free Food
(`free_food.py`).

## How notes are parsed

1. **Day.** An entry's date is the day it describes. An entry logged after midnight
   that was written before that night's sleep moves to the previous day only if that
   day has no entry of its own (a late log with the date left unchanged).
2. **Mood.** One entry: its mood is the day mood. Several entries: the last one (the
   end-of-day summary) sets the day mood, and every entry becomes a journal entry with
   its own mood and activities as tags.
3. **Activities** map to food source, activity or symptom (`taxonomy.py`).
4. **Line-per-item notes** (`<br>`): lines before the Sleep line are meals or
   supplements; lines after it are exercises or remarks (`lines.py`).
5. **Run-together notes** (mostly 2021–2022): the Reveille and Sleep times split the
   note into a meal part and an exercise part, cut further at prices, `X2` quantities,
   rep counts and bracketed comments, then split with a dictionary built from the
   line-per-item notes (`segment.py`). Leftovers go to the LLM.
6. **Validation** flags unusual sleep length, daytime bedtimes, high spend, foreign
   currency, time zones and anything guessed (`validate.py`).

## Garmin export

```bash
cd tools/daylio_migration
../../.venv/bin/python -m daylio_migration.garmin ../../data/<garmin-export>.zip
```

Reads a Garmin Connect data export (account → Data Management → Export Your Data)
straight from the zip and writes `data/migration/garmin_daily.json`: per day steps,
resting HR, all-day stress, Body Battery, respiration, sleep stages and score, overnight
HRV with its baseline range, and workouts. Only wellness and activity files are read;
profile, email and consent files are ignored. Units are converted: activity distance
is in centimetres, duration in milliseconds and calories in kilojoules in the export.
Sleep belongs to the date it ended on, as in the app.

## Import into the app

```bash
cd tools/daylio_migration
../../.venv/bin/python -m daylio_migration.app_export   # reads days.json and garmin_daily.json
```

Writes `data/migration/dailyrhythm_import.zip`, an app export in the v14 schema; import
it with Settings → Import Data. Meals and exercises link to their canonical name, keep
the original line as raw text, and are marked as having no time of day. Each Daylio
entry becomes a journal moment with its own mood and tags, and the original entries
are kept verbatim in `daylio_raw`. Food sources stay day-level tags, since Daylio
doesn't say which meal they were for. Importing the same zip twice adds nothing.

Clean-up applied on the way:

- A meal with sides ("Vegetarian maggie with long beans and curry veg") keeps its full
  name but links to its base dish ("Vegetarian maggie"), so sides don't make every
  plate a new food.
- Priced group events and gifts (farewells, KTV, weddings, ang bao) go to
  `spending_entries.csv`, not meals, so food spending means food.
- Bedtimes written in 12-hour form ("1115 Sleep") are read as evening when morning
  would make a 20-hour night (flag `bed_pm`).
- A count at the end of a name is the quantity ("Burger king 6"); a price inside a
  name is taken out (flag `price_in_name`); symptom notes stay out of meals.

