from daylio_migration.canonical import apply_aliases, compact_key, display_name, is_likely_same, propose
from daylio_migration.model import Day, ExerciseSet


def day(meals=(), exercises=()):
    return {"meals": [{"name": n} for n in meals], "exercises": [{"name": n} for n in exercises], "supplements": []}


def test_exact_variants_ignore_case_spaces_hyphens_and_plurals():
    assert compact_key("Sit-ups") == compact_key("situps") == compact_key("sit up") == compact_key("Sit ups")
    assert compact_key("Ham string stretch") == compact_key("Hamstring stretches")


def test_likely_typo_vs_different_dish():
    assert is_likely_same("Korean bbq chicken with rice", "Korean bbq chicken w rice")
    assert is_likely_same("Cream sauce spagehtti", "Cream sauce spaghetti")
    assert not is_likely_same("Dumpling ban mian", "Dumpling la mian")
    assert not is_likely_same("Fried rice chicken cutlet otah", "Fried rice chicken cutlet")


def test_display_name_sentence_case_keeps_brands():
    assert display_name("sit ups") == "Sit ups"
    assert display_name("Bicep Curls") == "Bicep curls"
    assert display_name("KFC zinger box") == "KFC zinger box"
    assert display_name("mcChicken muffin") == "McChicken muffin"


def test_proposals_group_and_rank():
    rows = propose([day(meals=["Wanton noodles"] * 5 + ["wanton noodles", "Wanton noodles soup", "Wanting noodles soup", "6 pc nuggets", "9 pc nuggets"],
                        exercises=["Sit ups"] * 3 + ["situps"])])
    by_variant = {(r["kind"], r["variant"]): r for r in rows}
    assert by_variant[("meals", "wanton noodles")]["how"] == "exact"
    # close spelling with a changed word: proposed, but left for a person to check
    assert by_variant[("meals", "Wanting noodles soup")]["canonical"] == "Wanton noodles soup"
    assert by_variant[("meals", "Wanting noodles soup")]["how"] == "check"
    assert by_variant[("exercises", "situps")]["canonical"] == "Sit ups"
    # different numbers are never merged
    assert ("meals", "9 pc nuggets") not in by_variant and ("meals", "6 pc nuggets") not in by_variant


def test_apply_sets_canonical_and_keeps_original():
    d = Day(date="2024-01-01", mood=3, entries=[], exercises=[ExerciseSet(text="60 situps", name="situps")])
    apply_aliases([d], {("exercises", "situps"): "Sit ups"})
    assert (d.exercises[0].name, d.exercises[0].canonical) == ("situps", "Sit ups")


def test_synonyms_chain_through_spelling_variants():
    d = Day(date="2024-01-01", mood=3, entries=[], exercises=[])
    from daylio_migration.model import Meal
    d.meals = [Meal(text="maggie", name="maggie"), Meal(text="Cai Peng", name="Cai Peng")]
    aliases = {("meals", "maggie"): "Maggie", ("meals", "Maggie"): "Maggi",
               ("meals", "Cai Peng"): "Cai peng", ("meals", "Cai peng"): "Mixed rice"}
    apply_aliases([d], aliases)
    assert [m.canonical for m in d.meals] == ["Maggi", "Mixed rice"]
