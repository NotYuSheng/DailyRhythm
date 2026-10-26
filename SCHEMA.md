# Database schema

SQLite via sqflite. `DatabaseService.schemaVersion` is the current version; every
upgrade path is covered by `test/database/migration_test.dart`, which also checks an
upgraded database matches a fresh install.

## v13

Additive: no existing table or column is removed, so current screens keep working
while the garden UI is built.

### New tables

| Table | Purpose | Key columns |
|---|---|---|
| `day_checkins` | Quick daily ratings relative to a usual day, plus the garden's "today was mostly…" override | `date` (unique), `energy`, `stress`, `focus` (−2…+2, nullable), `plant_override` |
| `journal_entries` | Moments: free text with an optional mood of their own | `date`, `time` (nullable), `text`, `mood` (1–5, nullable), `source` (`app` / `daylio`) |
| `journal_entry_tags` | Activities/symptoms a moment is about | `entry_id`, `tag_id` |
| `food_items` | Canonical foods for autocomplete and calories | `name` (unique), `aliases` (JSON), `kcal`, `kcal_source`, `last_price` |
| `exercise_items` | Canonical exercises | `name` (unique), `aliases` (JSON), `category` (`strength` / `cardio` / `mobility`) |
| `health_metrics` | One value per day, metric and source (narrow table, so optional and irregular data fits) | `date`, `metric`, `value`, `source` — unique on (date, metric, source) |
| `health_workouts` | Workouts from Garmin / Health Connect / HealthKit | `start`, `type`, `duration_min`, `distance_km`, `kcal`, `avg_hr`, `max_hr`, `source` |
| `daylio_raw` | Original Daylio entries, kept verbatim so any parse can be redone | `date`, `logged_time`, `mood`, `activities`, `note` |

### New columns

| Table | Columns |
|---|---|
| `meal_entries` | `food_source` (takeout, fast_food, homemade, free, restaurant, food_court, delivery), `food_item_id`, `currency` (default SGD), `raw_text`, `time_known` (0 for Daylio meals, which have no time) |
| `exercise_entries` | `exercise_item_id`, `raw_text` |
| `tags` | `kind`: `activity`, `symptom` or `food_source` |
| `activity_entries` | `severity` (1–3, symptoms only, nullable) |

Indexes on `date` for every dated table (import duplicate checks were full scans).

### Metric names in `health_metrics`

`steps`, `resting_hr`, `active_kcal`, `intensity_minutes`, `stress_avg`, `stress_max`,
`body_battery_high`, `body_battery_low`, `body_battery_charged`, `body_battery_drained`,
`respiration_waking`, `sleep_minutes`, `sleep_deep_minutes`, `sleep_light_minutes`,
`sleep_rem_minutes`, `sleep_awake_minutes`, `sleep_score`, `sleep_stress_avg`, `hrv`,
`hrv_baseline_low`, `hrv_baseline_high`, `sleep_hr`, `sleep_respiration`, `spo2`,
`skin_temp_c`. Sources: `garmin_export`, `health_connect`, `healthkit`, `manual`; when
several exist for a day the app prefers garmin_export > health_connect/healthkit > manual.

### Not stored

The garden plant for a day is derived (from that day's activity tags, sleep, movement
and moments), not stored, so it always reflects edits. Only the user's override is
stored, in `day_checkins.plant_override`.

## v14

| Table | Purpose | Key columns |
|---|---|---|
| `spending_entries` | Money spent on something that isn't a meal: group events (farewells, KTV, weddings) and gifts. Kept apart so food spending means food | `date`, `time`, `label`, `amount`, `currency`, `category` (`event` / `gift` / `other`), `raw_text` |

An imported meal that was really an event can be moved here from the meal
screen ("Not a meal: move to events & gifts").

## Export and import

Every table is exported as a CSV in the export zip. New columns go at the end of a
file so older exports still import; tags and catalog items are matched by name
because IDs differ between devices. Import runs in one transaction with duplicate
keys checked in memory (about 39k rows in 4 s on desktop) and reports progress.
Journal moments count as duplicates only if day, time, text, mood and tags all match,
because Daylio has entries in the same minute that differ only by mood or tags.

## Order of work

1. ✅ **3a** data layer: tables, migration, models, repositories, tests.
2. ✅ **3b** full import: the migration tool writes the new tables; the app's import reads
   them in one transaction with progress; the Daylio data is re-imported.
3. ✅ **3c** garden UI: Today's plant + check-in, month garden, moments.
