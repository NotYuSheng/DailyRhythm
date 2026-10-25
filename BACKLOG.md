# Backlog

Work agreed but not started. Newest first.

## Mood tracking redesign

The 5-point day mood barely moves (85% of Daylio days are "meh"), so it can't show
what affects how a day goes. Proposal under discussion:

- Keep the day mood for continuity with five years of Daylio data.
- Add a few quick daily ratings relative to a usual day (e.g. energy, stress, focus),
  centred on "usual" so small differences get recorded.
- Use journal moments (mood + activity tags) for notable events during the day.
- Use wearable data as an objective layer: sleep, resting HR and steps through
  Health Connect / HealthKit. Garmin stress, Body Battery and HRV are not shared
  through either, so they're only available for personal analysis via the
  `python-garminconnect` backfill script (brief, phase 6).

## Calories per food item

Store calories on the canonical food item, not on each meal, so logging stays a
lookup (calories × quantity, prefilled like the last price).

- The top 100 meal names cover ~48% of the 5,221 Daylio meals (before alias cleanup),
  so a small table covers most logging.
- Sources, in order: Singapore HPB energy & nutrient composition database (local
  dishes; check its terms before using it in the published app), USDA FoodData
  Central (generic foods), Open Food Facts (packaged items), a one-time batch LLM
  estimate for the rest, and the user's own correction, which always wins.
- Record the source of each value and show values as estimates, not nutrition advice.

## Year and month in review

Computed summaries, not LLM-generated; an LLM may only phrase numbers already computed.

- Records and totals: most-eaten dish, spend by food source, exercise totals,
  streaks, latest bedtime.
- Firsts: new dishes and places.
- Trends and change points: sleep (≈7.2h in 2022 → ≈6.4h in 2026), spend, exercise
  consistency.
- Patterns with statistical guardrails (confidence intervals, minimum sample sizes,
  Benjamini–Hochberg correction, weak findings labelled exploratory): mood on
  symptom days, next-day effects of short sleep, foods before stomach aches.
- Prototype first as a local report from the Daylio migration output
  (`data/migration/days.json`, brief phase 2); port the insights that hold up to the app.
