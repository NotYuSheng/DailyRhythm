from daylio_migration.llm import _extract_array, verify


def test_accepts_exact_split():
    assert verify("Subway Bar chor mee Indo mee", ["Subway", "Bar chor mee", "Indo mee"])


def test_rejects_changed_or_invented_text():
    piece = "Subway Bar chor mee Indo mee"
    assert not verify(piece, ["Subway", "Bar chor mee"])  # dropped text
    assert not verify(piece, ["Subway", "Bak chor mee", "Indo mee"])  # spelling fixed
    assert not verify(piece, ["Indo mee", "Subway", "Bar chor mee"])  # reordered
    assert not verify(piece, ["Subway", "Bar chor mee", "Indo mee", "Coffee"])  # invented


def test_extracts_array_after_reasoning():
    assert _extract_array('<think>hmm [x]</think>\n["a", "b"]') == ["a", "b"]
    assert _extract_array("no json here") is None
