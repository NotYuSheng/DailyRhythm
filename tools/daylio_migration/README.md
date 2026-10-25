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

Output in `data/migration/`:

| File | Contents |
|---|---|
| `days.json` | One record per day: mood, wake/bed, meals, exercises, supplements, journal entries, activities by category, the raw Daylio entries, and flags |
| `review.csv` | Every flagged item with a blank `correction` column |
| `summary.txt` | Counts by parse method and flag |

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
