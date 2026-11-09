import 'package:daily_rhythm/features/journal/data/models/journal_entry.dart';
import 'package:daily_rhythm/features/journal/domain/highlights.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  JournalEntry m(int day, String text, int? mood) => JournalEntry(date: DateTime(2026, 3, day), text: text, mood: mood);

  test('highlights: good moods first, then the most said, only with words', () {
    final h = momentHighlights([
      m(1, 'Okay day', 3),
      m(2, 'A long walk by the sea with friends', 3),
      m(3, 'Great news', 5),
      m(4, '', 5),
      m(5, 'Fine', null),
    ]);
    expect(h.map((e) => e.text), ['Great news', 'A long walk by the sea with friends', 'Okay day']);
  });

  test('bad and awful moments aren\'t highlights', () {
    expect(momentHighlights([m(1, 'Argument at work', 2), m(2, 'Nice coffee', null)]).map((e) => e.text), ['Nice coffee']);
  });
}
