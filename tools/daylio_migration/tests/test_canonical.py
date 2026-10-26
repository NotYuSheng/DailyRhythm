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


def test_names_in_other_scripts_are_not_all_the_same():
    assert compact_key("炒饭") != compact_key("鸡饭")
    assert compact_key("🍜") != compact_key("🍣")
    rows = propose([day(meals=["炒饭", "鸡饭", "鸡饭"])])
    assert rows == []


def test_one_letter_word_changes_need_a_check():
    assert not is_likely_same("Dried bee hoon", "Fried bee hoon")


def test_a_rejected_merge_keeps_its_own_spellings():
    rows = propose([day(meals=["Wanton noodles soup"] * 5 + ["Wanting noodles soup"] * 3 + ["wanting noodles soup"])])
    by_variant = {r["variant"]: r for r in rows}
    assert (by_variant["wanting noodles soup"]["canonical"], by_variant["wanting noodles soup"]["how"]) == ("Wanting noodles soup", "exact")
    assert by_variant["Wanting noodles soup"]["canonical"] == "Wanton noodles soup"


def test_earlier_decisions_apply_only_to_the_same_proposal():
    from daylio_migration.canonical import merge_previous

    rows = [{"kind": "meals", "canonical": "B", "variant": "a", "count": 1, "how": "check", "approve": ""}]
    previous = [
        {"kind": "meals", "canonical": "A", "variant": "a", "count": 1, "how": "check", "approve": "yes"},
        {"kind": "meals", "canonical": "Maggi", "variant": "Maggie", "count": 0, "how": "synonym", "approve": "yes"},
    ]
    merged = merge_previous(rows, previous)
    assert [(r["variant"], r["canonical"], r["approve"]) for r in merged] == [("Maggie", "Maggi", "yes"), ("a", "B", "")]


def test_synonyms_win_over_generated_rows(tmp_path):
    from daylio_migration.canonical import load_aliases

    path = tmp_path / "aliases.csv"
    path.write_text(
        "kind,canonical,variant,count,how,approve\n"
        "meals,Maggi,maggie,0,synonym,yes\n"
        "meals,Maggie,maggie,4,exact,yes\n"
    )
    assert load_aliases(path)[("meals", "maggie")] == "Maggi"


def test_synonyms_apply_to_whole_words_inside_longer_names():
    from daylio_migration.canonical import replace_words

    words = [("maggie", "Maggi")]
    assert replace_words("Maggie goreng", words) == "Maggi goreng"
    assert replace_words("Fried maggie mee", words) == "Fried Maggi mee"
    assert replace_words("Maggies", words) == "Maggies"
    assert replace_words("Ommaggie", words) == "Ommaggie"


def test_word_synonyms_set_canonical_and_count_changes():
    from daylio_migration.model import Meal

    d = Day(date="2024-01-01", mood=3, entries=[], exercises=[])
    d.meals = [Meal(text="Maggie goreng", name="Maggie goreng"), Meal(text="Maggie", name="Maggie")]
    changed = apply_aliases([d], {("meals", "Maggie"): "Maggi"}, {"meals": [("maggie", "Maggi")]})
    assert [m.canonical for m in d.meals] == ["Maggi goreng", "Maggi"]
    assert changed == 1


def test_proposals_merge_names_that_match_after_synonyms():
    rows = propose([day(meals=["Maggi goreng"] * 2 + ["Maggie goreng"] * 3)], {"meals": [("maggie", "Maggi")]})
    by_variant = {r["variant"]: r for r in rows}
    assert (by_variant["Maggie goreng"]["canonical"], by_variant["Maggie goreng"]["how"]) == ("Maggi goreng", "exact")
    assert "Maggi goreng" not in by_variant


def test_load_synonyms_longest_first(tmp_path):
    from daylio_migration.canonical import load_synonyms

    path = tmp_path / "aliases.csv"
    path.write_text(
        "kind,canonical,variant,count,how,approve\n"
        "meals,Maggi,maggie,0,synonym,yes\n"
        "meals,Maggi mee,maggie mee,0,synonym,yes\n"
        "meals,Wanton noodles,wanton mee,3,exact,yes\n"
    )
    assert load_synonyms(path) == {"meals": [("maggie mee", "Maggi mee"), ("maggie", "Maggi")]}
