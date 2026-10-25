from daylio_migration.lines import AFTER_SLEEP, BEFORE_SLEEP
from daylio_migration.segment import Lexicon, parse_run_together


def lexicon(meals=(), exercises=()):
    lex = Lexicon()
    for name in meals:
        lex.add(BEFORE_SLEEP, name)
    for name in exercises:
        lex.add(AFTER_SLEEP, name)
    return lex


def test_splits_with_anchors_and_dictionary():
    lex = lexicon(["Nasi lemak", "Yong Tau foo"], ["Dumbbell curl to overhead press", "Push ups"])
    note = parse_run_together(
        "0700 Reveille Nasi lemak Yong Tau foo 0040 Sleep Dumbbell curl to overhead press Push ups", lex)
    assert (note.wake, note.bed) == ("07:00", "00:40")
    assert [m.name for m in note.meals] == ["Nasi lemak", "Yong Tau foo"]
    assert [e.name for e in note.exercises] == ["Dumbbell curl to overhead press", "Push ups"]
    assert note.flags == []


def test_prefers_known_longer_dishes():
    lex = lexicon(["Korean omelette chicken cutlet rice", "Korean omelette", "Egg McMuffin"])
    note = parse_run_together("0730 Reveille Egg McMuffin Korean omelette chicken cutlet rice 0100 Sleep", lex)
    assert [m.name for m in note.meals] == ["Egg McMuffin", "Korean omelette chicken cutlet rice"]


def test_cuts_at_quantities_counts_and_prices():
    lex = lexicon(["Coconut juice", "bread", "bread", "bread"], ["bicep curl", "pull ups"])
    note = parse_run_together("0900 Reveille X2 bread Coconut juice 4.50 0100 Sleep 20 bicep curl 8 pull ups", lex)
    assert [(m.name, m.quantity, m.price) for m in note.meals] == [("bread", 2, None), ("Coconut juice", None, 4.5)]
    assert [(e.name, e.reps) for e in note.exercises] == [("bicep curl", 20), ("pull ups", 8)]


def test_comment_ends_an_item():
    lex = lexicon(["Campbell chicken mushroom soup", "toaster bread"])
    note = parse_run_together("0600 Reveille Campbell chicken mushroom soup (bad) + x6 toaster bread 0000 Sleep", lex)
    assert [(m.name, m.comment) for m in note.meals] == [
        ("Campbell chicken mushroom soup", "bad"), ("toaster bread", None)]


def test_unknown_pieces_go_to_the_splitter():
    asked = []

    def splitter(piece, zone, hints):
        asked.append((piece, zone))
        return ["Subway", "Bar chor mee", "Indo mee"]

    note = parse_run_together("0930 Reveille Subway Bar chor mee Indo mee 0015 Sleep", Lexicon(), splitter)
    assert asked == [("Subway Bar chor mee Indo mee", BEFORE_SLEEP)]
    assert [m.name for m in note.meals] == ["Subway", "Bar chor mee", "Indo mee"]
    assert [f.code for f in note.flags] == ["llm_split"]


def test_without_splitter_keeps_piece_whole_and_flags_it():
    note = parse_run_together("0930 Reveille Subway Bar chor mee 0015 Sleep", Lexicon())
    assert [m.name for m in note.meals] == ["Subway Bar chor mee"]
    assert [f.code for f in note.flags] == ["unsplit"]
