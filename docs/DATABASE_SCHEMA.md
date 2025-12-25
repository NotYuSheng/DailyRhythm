# DailyRhythm Database Schema – Data Model Documentation

## Table of Contents

- [DailyRhythm Database Schema – Data Model Documentation](#dailyrhythm-database-schema--data-model-documentation)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Core Tracking Tables](#core-tracking-tables)
    - [`sleep_entries`](#sleep_entries)
    - [`meal_entries`](#meal_entries)
    - [`mood_entries`](#mood_entries)
    - [`exercise_entries`](#exercise_entries)
    - [`task_entries`](#task_entries)
    - [`activity_entries`](#activity_entries)
  - [Reference Tables](#reference-tables)
    - [`tags`](#tags)
  - [Supporting Tables](#supporting-tables)
    - [`nap_entries`](#nap_entries)

---

## Overview

DailyRhythm uses SQLite as its local database to store all user data. The schema is designed around daily tracking of various life activities including sleep, meals, mood, exercise, tasks, and general activities. All dates and timestamps are stored in ISO8601 format for consistency and timezone handling.

**Database Location**: `dailyrhythm.db` in application documents directory

**Key Design Principles**:
- All primary keys are auto-incrementing integers
- Dates stored as ISO8601 text strings for Flutter DateTime compatibility
- Tags stored as JSON arrays in relevant tables
- Nullable fields allow partial data entry
- No cascade deletes to prevent accidental data loss

---

## Core Tracking Tables

### `sleep_entries`

**Purpose**
Tracks daily sleep data including wake-up time, bedtime, total sleep hours, and naps. Each entry represents one calendar day.

**Important Data Model Note**
The sleep calculation model is bidirectional:
- `wakeUpTime`: The time the user woke up on this day
- `sleepTime`: The time the user went to bed on this day (to be used for the NEXT day's calculation)
- `totalHours`: Calculated as (previous day's `sleepTime`) to (current day's `wakeUpTime`)

If the previous day's sleep time was after midnight, the calculation adds 24 hours to handle the overnight period correctly.

**Columns**

| Column       | Type            | Constraints | Description                                                      |
|--------------|-----------------|-------------|------------------------------------------------------------------|
| `id`         | `INTEGER`       | PK          | Unique identifier for a sleep entry.                             |
| `date`       | `TEXT`          | NOT NULL    | Date of the entry in ISO8601 format (e.g., "2024-12-25").        |
| `wakeUpTime` | `TEXT`          | NULLABLE    | Time the user woke up in ISO8601 format (e.g., "2024-12-25T07:30:00"). |
| `sleepTime`  | `TEXT`          | NULLABLE    | Time the user went to bed in ISO8601 format (stored for next day's calculation). |
| `totalHours` | `REAL`          | NULLABLE    | Total hours slept (manually entered or auto-calculated).         |
| `napHours`   | `REAL`          | NULLABLE    | Total nap hours for the day.                                     |
| `tags`       | `TEXT`          | DEFAULT '[]'| JSON array of tag strings (e.g., '["Good Sleep", "Restless"]'). |

**Indexes**

```sql
CREATE INDEX idx_sleep_date ON sleep_entries(date);
```

**Relationships**

- Referenced by `nap_entries.sleepEntryId` — links nap records to daily sleep entry.

**Example Data**

```sql
INSERT INTO sleep_entries (date, wakeUpTime, sleepTime, totalHours, napHours, tags)
VALUES ('2024-12-25', '2024-12-25T07:30:00.000', '2024-12-25T23:00:00.000', 7.5, 0.5, '["Good Sleep"]');
```

---

### `meal_entries`

**Purpose**
Tracks individual meals and food consumption including nutritional and cost information.

**Columns**

| Column     | Type       | Constraints | Description                                                    |
|------------|------------|-------------|----------------------------------------------------------------|
| `id`       | `INTEGER`  | PK          | Unique identifier for a meal entry.                            |
| `date`     | `TEXT`     | NOT NULL    | Date of the meal in ISO8601 format (e.g., "2024-12-25").       |
| `time`     | `TEXT`     | NOT NULL    | Time of the meal in ISO8601 format (e.g., "2024-12-25T12:30:00"). |
| `name`     | `TEXT`     | NOT NULL    | Name/description of the meal (e.g., "Chicken Rice").           |
| `quantity` | `INTEGER`  | NOT NULL    | Quantity/servings consumed.                                    |
| `price`    | `REAL`     | NOT NULL    | Cost of the meal in local currency.                            |
| `calories` | `INTEGER`  | NULLABLE    | Estimated calorie content.                                     |
| `tags`     | `TEXT`     | DEFAULT '[]'| JSON array of tag strings (e.g., '["Lunch", "Healthy"]').     |
| `notes`    | `TEXT`     | NULLABLE    | Additional notes about the meal.                               |

**Indexes**

```sql
CREATE INDEX idx_meal_date ON meal_entries(date);
CREATE INDEX idx_meal_time ON meal_entries(time);
```

**Relationships**

- None (standalone tracking table).

**Example Data**

```sql
INSERT INTO meal_entries (date, time, name, quantity, price, calories, tags, notes)
VALUES ('2024-12-25', '2024-12-25T12:30:00.000', 'Chicken Rice', 1, 5.50, 650, '["Lunch", "Local"]', 'Extra chili');
```

---

### `mood_entries`

**Purpose**
Captures mood snapshots throughout the day with a 1-5 rating scale and optional notes.

**Columns**

| Column      | Type      | Constraints              | Description                                                    |
|-------------|-----------|--------------------------|----------------------------------------------------------------|
| `id`        | `INTEGER` | PK                       | Unique identifier for a mood entry.                            |
| `date`      | `TEXT`    | NOT NULL                 | Date of the mood entry in ISO8601 format (e.g., "2024-12-25"). |
| `timestamp` | `TEXT`    | NOT NULL                 | Exact time of the mood entry in ISO8601 format.                |
| `moodLevel` | `INTEGER` | NOT NULL, CHECK (1-5)    | Mood rating from 1 (very bad) to 5 (very good).                |
| `emoji`     | `TEXT`    | NOT NULL                 | Emoji representation of mood (e.g., "😊", "😢").               |
| `notes`     | `TEXT`    | NULLABLE                 | Optional notes about the mood/context.                         |

**Indexes**

```sql
CREATE INDEX idx_mood_date ON mood_entries(date);
CREATE INDEX idx_mood_timestamp ON mood_entries(timestamp);
```

**Relationships**

- None (standalone tracking table).

**Example Data**

```sql
INSERT INTO mood_entries (date, timestamp, moodLevel, emoji, notes)
VALUES ('2024-12-25', '2024-12-25T14:30:00.000', 4, '😊', 'Great day at work');
```

---

### `exercise_entries`

**Purpose**
Tracks exercise activities with support for running, weight lifting, and general exercises. Different exercise types use different fields.

**Exercise Types**

- **Run**: Uses `runType`, `distance`, `duration`, `pace`, and interval fields
- **Weight Lifting**: Uses `exerciseName`, `equipmentType`, `reps`, `weight`, `sets`
- **General**: Uses `exerciseName` and `duration`

**Columns**

| Column             | Type      | Constraints | Description                                                       |
|--------------------|-----------|-------------|-------------------------------------------------------------------|
| `id`               | `INTEGER` | PK          | Unique identifier for an exercise entry.                          |
| `date`             | `TEXT`    | NOT NULL    | Date of the exercise in ISO8601 format.                           |
| `timestamp`        | `TEXT`    | NOT NULL    | Time of the exercise in ISO8601 format.                           |
| `type`             | `TEXT`    | NOT NULL    | Type of exercise ("run", "weightLifting", "general").             |
| `runType`          | `TEXT`    | NULLABLE    | Type of run ("regular", "interval", "longRun") — for runs only.   |
| `distance`         | `REAL`    | NULLABLE    | Distance in kilometers — for runs only.                           |
| `duration`         | `REAL`    | NULLABLE    | Duration in minutes.                                              |
| `pace`             | `REAL`    | NULLABLE    | Pace in min/km — for runs only.                                   |
| `intervalDistance` | `REAL`    | NULLABLE    | Interval distance in meters — for interval runs.                  |
| `intervalTime`     | `REAL`    | NULLABLE    | Interval time in seconds — for interval runs.                     |
| `restTime`         | `REAL`    | NULLABLE    | Rest time between intervals in seconds.                           |
| `intervalCount`    | `INTEGER` | NULLABLE    | Number of intervals completed.                                    |
| `exerciseName`     | `TEXT`    | NULLABLE    | Name of exercise — for weight lifting and general.                |
| `equipmentType`    | `TEXT`    | NULLABLE    | Equipment used — for weight lifting.                              |
| `reps`             | `INTEGER` | NULLABLE    | Repetitions per set — for weight lifting.                         |
| `weight`           | `REAL`    | NULLABLE    | Weight in kg — for weight lifting.                                |
| `sets`             | `INTEGER` | NULLABLE    | Number of sets — for weight lifting.                              |
| `notes`            | `TEXT`    | NULLABLE    | Additional notes about the exercise.                              |

**Indexes**

```sql
CREATE INDEX idx_exercise_date ON exercise_entries(date);
CREATE INDEX idx_exercise_type ON exercise_entries(type);
```

**Relationships**

- None (standalone tracking table).

**Example Data**

```sql
-- Running entry
INSERT INTO exercise_entries (date, timestamp, type, runType, distance, duration, pace)
VALUES ('2024-12-25', '2024-12-25T06:00:00.000', 'run', 'regular', 5.0, 30.0, 6.0);

-- Weight lifting entry
INSERT INTO exercise_entries (date, timestamp, type, exerciseName, equipmentType, reps, weight, sets)
VALUES ('2024-12-25', '2024-12-25T18:00:00.000', 'weightLifting', 'Bench Press', 'barbell', 10, 60.0, 3);
```

---

### `task_entries`

**Purpose**
Tracks daily tasks and activities that don't fit into other categories.

**Columns**

| Column      | Type      | Constraints | Description                                                    |
|-------------|-----------|-------------|----------------------------------------------------------------|
| `id`        | `INTEGER` | PK          | Unique identifier for a task entry.                            |
| `date`      | `TEXT`    | NOT NULL    | Date of the task in ISO8601 format.                            |
| `timestamp` | `TEXT`    | NOT NULL    | Time the task was logged in ISO8601 format.                    |
| `taskType`  | `TEXT`    | NOT NULL    | Type/category of the task (e.g., "Work", "Personal").          |
| `notes`     | `TEXT`    | NULLABLE    | Description or notes about the task.                           |

**Indexes**

```sql
CREATE INDEX idx_task_date ON task_entries(date);
```

**Relationships**

- None (standalone tracking table).

**Example Data**

```sql
INSERT INTO task_entries (date, timestamp, taskType, notes)
VALUES ('2024-12-25', '2024-12-25T09:00:00.000', 'Work', 'Completed project documentation');
```

---

### `activity_entries`

**Purpose**
Tracks general activities using a tag-based system. Activities are categorized by user-defined tags from the `tags` table.

**Columns**

| Column      | Type      | Constraints          | Description                                                    |
|-------------|-----------|----------------------|----------------------------------------------------------------|
| `id`        | `INTEGER` | PK                   | Unique identifier for an activity entry.                       |
| `date`      | `TEXT`    | NOT NULL             | Date of the activity in ISO8601 format.                        |
| `timestamp` | `TEXT`    | NOT NULL             | Time of the activity in ISO8601 format.                        |
| `tagId`     | `INTEGER` | FK → `tags`, NOT NULL| Tag that categorizes this activity.                            |
| `notes`     | `TEXT`    | NULLABLE             | Optional notes about the activity.                             |

**Indexes**

```sql
CREATE INDEX idx_activity_date ON activity_entries(date);
CREATE INDEX idx_activity_tag ON activity_entries(tagId);
```

**Relationships**

- FK to `tags(id)` — categorizes the activity.

**Example Data**

```sql
INSERT INTO activity_entries (date, timestamp, tagId, notes)
VALUES ('2024-12-25', '2024-12-25T15:00:00.000', 5, 'Watched a movie with family');
```

---

## Reference Tables

### `tags`

**Purpose**
Master table for user-defined tags used to categorize activities. Tags are organized by category and can have custom colors and emojis.

**Columns**

| Column      | Type      | Constraints      | Description                                                    |
|-------------|-----------|------------------|----------------------------------------------------------------|
| `id`        | `INTEGER` | PK               | Unique identifier for a tag.                                   |
| `name`      | `TEXT`    | NOT NULL, UNIQUE | Display name of the tag (e.g., "Reading", "Exercise").         |
| `emoji`     | `TEXT`    | NOT NULL         | Emoji icon for the tag (e.g., "📚", "🏃").                     |
| `category`  | `TEXT`    | NOT NULL         | Category grouping (e.g., "Work", "Leisure", "Health").         |
| `color`     | `TEXT`    | NULLABLE         | Optional color code for UI display (e.g., "#FF5722").          |
| `sortOrder` | `INTEGER` | NULLABLE         | Custom sort order for display in UI.                           |

**Indexes**

```sql
CREATE INDEX idx_tag_category ON tags(category);
CREATE INDEX idx_tag_sort ON tags(sortOrder);
```

**Relationships**

- Referenced by `activity_entries.tagId` — links activities to their category tags.

**Example Data**

```sql
INSERT INTO tags (name, emoji, category, color, sortOrder)
VALUES
  ('Reading', '📚', 'Leisure', '#FF5722', 1),
  ('Exercise', '🏃', 'Health', '#4CAF50', 2),
  ('Work', '💼', 'Work', '#2196F3', 3);
```

---

## Supporting Tables

### `nap_entries`

**Purpose**
Tracks individual nap sessions within a day. Naps are linked to the daily sleep entry and contribute to the total `napHours` field.

**Columns**

| Column         | Type      | Constraints                         | Description                                                    |
|----------------|-----------|-------------------------------------|----------------------------------------------------------------|
| `id`           | `INTEGER` | PK                                  | Unique identifier for a nap entry.                             |
| `sleepEntryId` | `INTEGER` | FK → `sleep_entries`, NOT NULL      | Parent sleep entry for this day.                               |
| `startTime`    | `TEXT`    | NOT NULL                            | Start time of the nap in ISO8601 format.                       |
| `endTime`      | `TEXT`    | NOT NULL                            | End time of the nap in ISO8601 format.                         |
| `duration`     | `REAL`    | NOT NULL                            | Duration of the nap in hours (calculated from start/end).      |

**Indexes**

```sql
CREATE INDEX idx_nap_sleep_entry ON nap_entries(sleepEntryId);
```

**Relationships**

- FK to `sleep_entries(id)` — links nap to the day's sleep entry.

**Example Data**

```sql
INSERT INTO nap_entries (sleepEntryId, startTime, endTime, duration)
VALUES (1, '2024-12-25T14:00:00.000', '2024-12-25T14:30:00.000', 0.5);
```

---

## Schema Version History

| Version | Date       | Changes                                                      |
|---------|------------|--------------------------------------------------------------|
| 1.0     | 2024-12-25 | Initial schema with sleep, meal, mood, exercise, task, activity, tags, and nap tables. |

---

## Notes

**Date and Time Handling**:
- All dates and timestamps are stored as ISO8601 text strings
- Flutter DateTime objects are converted to ISO8601 on save
- ISO8601 strings are parsed back to DateTime on read

**JSON Fields**:
- Tags in `sleep_entries` and `meal_entries` are stored as JSON arrays
- Serialized using `jsonEncode()` and deserialized using `jsonDecode()`

**Sleep Calculation Model**:
- Each day's sleep entry stores that day's bedtime for the NEXT day's calculation
- If previous day has no sleep time recorded, current day shows "unknown" for sleep hours
- Past-midnight bedtimes are handled by adding 24 hours to duration calculation

**Metrics and Analytics**:
- Metrics are calculated on-the-fly from raw data
- No pre-aggregated metrics tables
- Date range queries use indexed date fields for performance
