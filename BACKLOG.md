# Backlog

Work agreed but not started. Newest first.

Queued work is tracked as GitHub issues. Built and merged into `dev` (the issues close
when `dev` reaches `main`): exercise autocomplete (#9), word-level aliases in the
migration (#10), Metrics on mood/energy/stress/focus and fun facts (#11), the Tags
screen (#12), month and year recap (#13), calories per food (#15), Health Connect /
HealthKit sync and Garmin import (#16). Still open: plant illustrations and Rive (#14,
prototypes on the design canvas's "Plant art & motion" page), offline calorie datasets
(#31) and the sleep picker repro (#17). The sections below keep the design notes those
issues refer to.

## Design direction: the garden (chosen 2026-10-25)

Prototype: "DailyRhythm redesign" design canvas, row **B3 · Warm: garden**, plus the
"What grows when" sheet (https://claude.ai/artifact/5kGywedoqNP2C8EHV7H5iH, private).
Other rows on that canvas were explored and not chosen.

Every logged day grows a plant in a pot:

| Day mostly about (from activity tags) | Plant |
|---|---|
| Exercise | Sunflower |
| Rest | Succulent |
| Social / family | Tulip |
| Work | Cactus |
| Study | Fern |
| Gaming / videos | Monstera |
| A mix | Sprout |
| Big days (trips, birthdays) | Little tree |

- **A memory garden (2026-10-27):** a plant says only what kind of day it was. Size,
  leaves and blooms carry no data; every number (sleep, steps, mood) is in Metrics.
  The garden is for looking back: tap a plant to see why it grew ("From Work and
  Study") and open the day. Today logs, Garden remembers, Metrics finds patterns.
- Missed days are empty pots. Nothing wilts, dies or loses a streak.
- Screens: Today's plant (with a "today was mostly…" override), the month as a garden,
  and the warm B row's calendar, rhythm zone, recap and sticker ideas where they fit.
- Look: warm pastels on a soft green ground, rounded Nunito type, gentle neutral
  wording with no advice (typical ranges are shown as reference bands, not advice), subtle sway animation (off with reduced motion).
- The prototype draws plants in code. Production plants need real illustration
  (commissioned or licence-checked asset set), animated with Rive.

**Built (3c, 2026-10-25):** the Today tab (plant, "today was mostly…", stats, check-in,
moments) and the month garden, in `lib/features/garden/`. The plants are the
prototype's drawings ported to SVG; they stay until real illustrations replace them.
How the plant is picked when the user doesn't choose:

- Each kind of activity counts once a day, however many of its tags were used.
- Tags logged on 60%+ of the previous 8 weeks are routine and only decide when nothing
  else stands out; several kinds, or none, give a sprout ("a bit of everything").
  With the Daylio history (the same five tags almost daily) most past days are
  sprouts; social days, intense workouts and the like stand out.
- Metrics shows an overview for every period: every day coloured by a measure, mood and
  sleep and a table grouped to fit (a week by day, a month by week, a year by month,
  all time by year), and days that stood out. Garden has a year of
  gardens: each month's plants, tapping through to its review.
- **Profile and ranges (2026-10-28):** an optional profile (year of birth, height,
  weight, sex) in Settings, kept on the device. Metrics marks sleep and calories
  outside the user's typical range (sleep by age; calories by Mifflin–St Jeor times
  an activity factor from the period's average steps). Every day with meals logged
  counts toward calories (the user often eats two meals a day).
- **Weight log:** weight is the `weight_kg` health metric (manual source). Log it from
  Metrics (Weight section) or by changing it in the profile; the latest weight is the
  profile's, so the calorie range follows it. The trend is the real check on whether
  logged calories undercount.

Still to do: year/month recap (#13) and stickers from the warm B row, real
illustrations with Rive animation (#14).

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
- Must work for any user, not just the developer's diet: each user's food item links
  once (user-confirmed) to a reference food; later logs are a lookup.
- Reference data bundled on device per region, searched offline:
  - USDA FoodData Central: generic foods, public domain.
  - SG FoodID (HPB): licence in its terms §10 allows commercial use and distribution in
    apps, with a conspicuous attribution notice + licence link and no implied HPB
    endorsement. Check whether hawker dishes (old FOCOS data) are still included.
  - Other national tables per region later (UK CoFID, AUSNUT, Canadian CNF); check each licence.
- Packaged food: barcode lookup in Open Food Facts (online; only the barcode is sent;
  ODbL — attribution, share-alike if redistributing their data).
- New foods: search with synonyms (local names) and show top matches to confirm;
  no match → build from ingredients, copy and adjust a similar food, or an opt-in
  AI estimate that sends only the dish name.
- Portions as small/regular/large multipliers plus quantity.
- Record each value's source (usda / sgfoodid / off / estimate / user) and show values
  as estimates, not nutrition advice.
- Developer's own history: auto-match the cleaned Daylio food names above a confidence
  threshold, review the rest, estimate the remainder with the local LLM (personal use).

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
