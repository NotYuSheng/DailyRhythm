import json
import zipfile

from daylio_migration.garmin import daily_metrics, read_export


def make_export(tmp_path):
    """A minimal export with one day of each file kind, plus files to ignore."""
    files = {
        "DI_CONNECT/DI-Connect-Aggregator/UDSFile_2026-03-07_2026-03-09.json": [{
            "calendarDate": "2026-03-08",
            "wellnessStartTimeLocal": "2026-03-08T00:00:00.0",
            "wellnessStartTimeGmt": "2026-03-07T16:00:00.0",
            "totalSteps": 7117,
            "restingHeartRate": 54,
            "allDayStress": {"aggregatorList": [
                {"type": "ASLEEP", "averageStressLevel": 11},
                {"type": "TOTAL", "averageStressLevel": 31, "maxStressLevel": 92},
            ]},
            "bodyBattery": {"chargedValue": 77, "drainedValue": 39, "bodyBatteryStatList": [
                {"bodyBatteryStatType": "HIGHEST", "statsValue": 86},
                {"bodyBatteryStatType": "LOWEST", "statsValue": 9},
            ]},
        }, {
            "calendarDate": "2026-03-09",
            "totalSteps": -1,  # Garmin's "no data"
            "allDayStress": {"aggregatorList": [{"type": "TOTAL", "averageStressLevel": -2}]},
        }],
        "DI_CONNECT/DI-Connect-Wellness/2026-03-07_2026-03-09_1_sleepData.json": [{
            "calendarDate": "2026-03-08",
            "sleepStartTimestampGMT": "2026-03-07T17:26:00.0",
            "sleepEndTimestampGMT": "2026-03-08T00:23:00.0",
            "deepSleepSeconds": 5160, "lightSleepSeconds": 16260, "remSleepSeconds": 3000,
            "awakeSleepSeconds": 600,
            "sleepScores": {"overallScore": 79},
        }, {"calendarDate": "2026-03-09", "retro": False}],  # unmeasured night
        "DI_CONNECT/DI-Connect-Wellness/2026-03-07_2026-03-09_1_healthStatusData.json": [{
            "calendarDate": "2026-03-08",
            "metrics": [
                {"type": "HRV", "value": 59.0, "baselineLowerLimit": 43.0, "baselineUpperLimit": 65.0},
                {"type": "SPO2", "value": None},
            ],
        }],
        "DI_CONNECT/DI-Connect-Fitness/me_1_summarizedActivities.json": [{"summarizedActivitiesExport": [{
            "activityType": "running",
            "startTimeLocal": 1772991480000.0,  # 2026-03-08 17:38 local
            "duration": 1662000.0,  # ms
            "distance": 362000.0,  # cm
            "calories": 1029.3,  # kJ
            "avgHr": 162.0,
        }]}],
        "DI_CONNECT/DI-Connect-User/user_profile.json": {"email": "someone@example.com"},
    }
    path = tmp_path / "export.zip"
    with zipfile.ZipFile(path, "w") as archive:
        for name, content in files.items():
            archive.writestr(name, json.dumps(content))
    return path


def test_reads_daily_sleep_hrv_and_workouts(tmp_path):
    days = {d["date"]: d for d in daily_metrics(read_export(make_export(tmp_path)))}
    day = days["2026-03-08"]
    m = day["metrics"]

    assert (m["steps"], m["resting_hr"], m["stress_avg"], m["stress_max"]) == (7117, 54, 31, 92)
    assert (m["body_battery_high"], m["body_battery_low"], m["body_battery_charged"]) == (86, 9, 77)
    assert (m["sleep_minutes"], m["sleep_deep_minutes"], m["sleep_score"]) == (407, 86, 79)
    assert (m["hrv"], m["hrv_baseline_low"], m["hrv_baseline_high"]) == (59, 43, 65)
    assert "spo2" not in m
    # GMT times shifted by that day's own local offset
    assert (day["sleep_start"], day["sleep_end"]) == ("2026-03-08T01:26", "2026-03-08T08:23")
    assert day["workouts"] == [{
        "type": "running", "start": "2026-03-08T17:38", "duration_min": 27.7,
        "distance_km": 3.62, "kcal": 246, "avg_hr": 162.0, "max_hr": None,
    }]


def test_skips_no_data_values_and_unmeasured_nights(tmp_path):
    days = {d["date"]: d for d in daily_metrics(read_export(make_export(tmp_path)))}
    # 2026-03-09 had only "no data" markers, so it produces no record at all.
    assert "2026-03-09" not in days


def test_ignores_profile_files(tmp_path):
    records = read_export(make_export(tmp_path))
    assert "someone@example.com" not in json.dumps(records)
