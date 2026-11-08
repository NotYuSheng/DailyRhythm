from daylio_migration.model import Day
from daylio_migration.validate import validate


def day(date, wake=None, bed=None):
    return Day(date=date, mood=3, entries=[], wake=wake, bed=bed)


def test_a_morning_bedtime_that_makes_a_20_hour_night_is_read_as_evening():
    days = [day("2022-01-10", wake="08:00", bed="11:15"), day("2022-01-11", wake="10:00", bed="00:30")]
    validate(days)
    assert days[0].bed == "23:15"
    assert "bed_pm" in [f.code for f in days[0].flags]
    assert "sleep_length" not in [f.code for f in days[1].flags]


def test_a_real_late_morning_bedtime_is_kept():
    # Asleep 09:00, up at 15:00: six hours either way round, so keep it.
    days = [day("2022-01-10", bed="09:00"), day("2022-01-11", wake="15:00")]
    validate(days)
    assert days[0].bed == "09:00"


def test_without_the_next_wake_nothing_changes():
    days = [day("2022-01-10", bed="11:15")]
    validate(days)
    assert days[0].bed == "11:15"
