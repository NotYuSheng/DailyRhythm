"""Reads daily health metrics from a Garmin Connect data export.

The export (garmin.com account -> Data Management -> Export Your Data) is a
zip of JSON files. Only the wellness and activity files are read; profile,
email and consent files are ignored. The format is undocumented, so every
field is optional and missing or negative ("no data") values are skipped.

    python -m daylio_migration.garmin data/garmin_export.zip --out data/migration

Writes garmin_daily.json: one record per date with a ``metrics`` map and the
day's ``workouts``. Sleep metrics belong to the date the sleep ended on,
matching the app, where a day's sleep is the night before it.
"""

from __future__ import annotations

import argparse
import json
import re
import zipfile
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

SOURCE = "garmin_export"
DEFAULT_UTC_OFFSET = timedelta(hours=8)  # used only when a day has no local time

FILES = {
    "daily": re.compile(r"(^|/)UDSFile_[^/]*\.json$"),
    "sleep": re.compile(r"(^|/)[^/]*_sleepData\.json$"),
    "health": re.compile(r"(^|/)[^/]*_healthStatusData\.json$"),
    "activities": re.compile(r"(^|/)[^/]*_summarizedActivities\.json$"),
}


def _number(value):
    """Garmin uses -1/-2 (and sometimes 0) for 'not measured'."""
    if isinstance(value, (int, float)) and not isinstance(value, bool) and value >= 0:
        return value
    return None


def _gmt(value: str | float | None) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value / 1000, timezone.utc).replace(tzinfo=None)
    return datetime.fromisoformat(str(value).split(".")[0])


def read_export(path: Path) -> dict[str, list]:
    """Returns the records of each known file kind, from a zip or a folder."""
    records: dict[str, list] = defaultdict(list)

    def add(name: str, load) -> None:
        for kind, pattern in FILES.items():
            if pattern.search(name):
                data = load()
                if kind == "activities":
                    data = [a for block in data for a in block.get("summarizedActivitiesExport", [])]
                records[kind].extend(data)

    if path.is_dir():
        for file in sorted(path.rglob("*.json")):
            add(file.as_posix(), lambda f=file: json.loads(f.read_text()))
    else:
        with zipfile.ZipFile(path) as archive:
            for name in sorted(archive.namelist()):
                add(name, lambda n=name: json.loads(archive.read(n)))
    return records


def daily_metrics(records: dict[str, list]) -> list[dict]:
    days: dict[str, dict] = defaultdict(lambda: {"metrics": {}, "workouts": []})
    offsets: dict[str, timedelta] = {}

    def put(date: str, name: str, value) -> None:
        if (value := _number(value)) is not None:
            days[date]["metrics"][name] = value

    for r in records["daily"]:
        date = r.get("calendarDate")
        if not date:
            continue
        local, gmt = r.get("wellnessStartTimeLocal"), r.get("wellnessStartTimeGmt")
        if local and gmt:
            offsets[date] = _gmt(local) - _gmt(gmt)
        put(date, "steps", r.get("totalSteps"))
        put(date, "resting_hr", r.get("restingHeartRate"))
        put(date, "active_kcal", r.get("activeKilocalories"))
        moderate, vigorous = _number(r.get("moderateIntensityMinutes")), _number(r.get("vigorousIntensityMinutes"))
        if moderate is not None or vigorous is not None:  # Garmin counts vigorous minutes double
            put(date, "intensity_minutes", (moderate or 0) + 2 * (vigorous or 0))
        stress = next((a for a in (r.get("allDayStress") or {}).get("aggregatorList", []) if a.get("type") == "TOTAL"), {})
        put(date, "stress_avg", stress.get("averageStressLevel"))
        put(date, "stress_max", stress.get("maxStressLevel"))
        battery = r.get("bodyBattery") or {}
        stats = {s.get("bodyBatteryStatType"): s.get("statsValue") for s in battery.get("bodyBatteryStatList", [])}
        put(date, "body_battery_high", stats.get("HIGHEST"))
        put(date, "body_battery_low", stats.get("LOWEST"))
        put(date, "body_battery_charged", battery.get("chargedValue"))
        put(date, "body_battery_drained", battery.get("drainedValue"))
        put(date, "respiration_waking", (r.get("respiration") or {}).get("avgWakingRespirationValue"))

    for r in records["sleep"]:
        date = r.get("calendarDate")
        stages = [_number(r.get(k)) for k in ("deepSleepSeconds", "lightSleepSeconds", "remSleepSeconds")]
        if not date or not any(stages):
            continue  # nap-only or unmeasured night
        offset = offsets.get(date, DEFAULT_UTC_OFFSET)
        start, end = _gmt(r.get("sleepStartTimestampGMT")), _gmt(r.get("sleepEndTimestampGMT"))
        if start and end:
            days[date]["sleep_start"] = (start + offset).isoformat(timespec="minutes")
            days[date]["sleep_end"] = (end + offset).isoformat(timespec="minutes")
        put(date, "sleep_minutes", sum(s or 0 for s in stages) / 60)
        put(date, "sleep_deep_minutes", (stages[0] or 0) / 60)
        put(date, "sleep_light_minutes", (stages[1] or 0) / 60)
        put(date, "sleep_rem_minutes", (stages[2] or 0) / 60)
        put(date, "sleep_awake_minutes", (_number(r.get("awakeSleepSeconds")) or 0) / 60)
        put(date, "sleep_score", (r.get("sleepScores") or {}).get("overallScore"))
        put(date, "sleep_stress_avg", r.get("avgSleepStress"))

    names = {"HRV": "hrv", "HR": "sleep_hr", "RESPIRATION": "sleep_respiration", "SPO2": "spo2", "SKIN_TEMP_C": "skin_temp_c"}
    for r in records["health"]:
        date = r.get("calendarDate")
        for metric in r.get("metrics", []) if date else []:
            name = names.get(metric.get("type"))
            if not name:
                continue
            put(date, name, metric.get("value"))
            if name == "hrv":  # personal baseline range, for "is tonight unusual?"
                put(date, "hrv_baseline_low", metric.get("baselineLowerLimit"))
                put(date, "hrv_baseline_high", metric.get("baselineUpperLimit"))

    for a in records["activities"]:
        start = _gmt(a.get("startTimeLocal"))
        if not start or not _number(a.get("duration")):
            continue
        days[start.date().isoformat()]["workouts"].append({
            "type": a.get("activityType"),
            "start": start.isoformat(timespec="minutes"),
            "duration_min": round(a["duration"] / 60000, 1),  # milliseconds
            "distance_km": round(a["distance"] / 100000, 2) if _number(a.get("distance")) else None,  # centimetres
            # The export's activity calories are kilojoules: a 28-minute 3.6 km run
            # reads ~1030, more than that whole day's 358 active kcal.
            "kcal": round(a["calories"] / 4.184) if _number(a.get("calories")) else None,
            "avg_hr": _number(a.get("avgHr")),
            "max_hr": _number(a.get("maxHr")),
        })

    return [{"date": d, "source": SOURCE, **days[d]} for d in sorted(days) if days[d]["metrics"] or days[d]["workouts"]]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("export", type=Path, help="Garmin export zip, or a folder of its JSON files")
    parser.add_argument("--out", type=Path, default=Path(__file__).resolve().parents[3] / "data" / "migration")
    args = parser.parse_args()

    days = daily_metrics(read_export(args.export))
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "garmin_daily.json").write_text(json.dumps(days, indent=1))

    coverage = defaultdict(int)
    for day in days:
        for name in day["metrics"]:
            coverage[name] += 1
    print(f"{len(days)} days, {days[0]['date']} to {days[-1]['date']}" if days else "no days found")
    for name, count in sorted(coverage.items(), key=lambda kv: -kv[1]):
        print(f"  {name}: {count}")
    print(f"  workouts: {sum(len(d['workouts']) for d in days)}")
    print(f"Wrote {args.out / 'garmin_daily.json'}")


if __name__ == "__main__":
    main()
