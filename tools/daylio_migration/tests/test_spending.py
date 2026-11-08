from daylio_migration.lines import parse_meal
from daylio_migration.model import Day
from daylio_migration.spending import load_events, mark_events, spending_kind


def test_event_words_on_a_big_bill_are_spending():
    assert spending_kind("Farewell dinner", 120) == "event"
    assert spending_kind("Party wings", 9) is None
    assert spending_kind("Wedding ang bao", 200) == "gift"


def test_confirmed_events_are_moved_to_spending(tmp_path):
    path = tmp_path / "events.csv"
    path.write_text("date,name\n2024-05-01,Steamboat with friends\n")
    d = Day(date="2024-05-01", mood=None, entries=[],
            meals=[parse_meal("Steamboat with friends $150", []), parse_meal("Chicken rice 4", [])])
    assert mark_events([d], load_events(path)) == 1
    assert [m.spending for m in d.meals] == ["event", None]


def test_no_events_file_changes_nothing(tmp_path):
    assert load_events(tmp_path / "events.csv") == set()
