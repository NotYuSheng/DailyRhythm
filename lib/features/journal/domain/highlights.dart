import '../data/models/journal_entry.dart';

/// Moments worth seeing again: ones with words, leaving out bad and awful
/// ones, good moods first, then the ones with the most to say. A moment
/// without a mood counts as neutral.
List<JournalEntry> momentHighlights(Iterable<JournalEntry> moments, {int max = 3}) {
  final worth = [
    for (final m in moments)
      if (m.text.trim().isNotEmpty && (m.mood ?? 3) >= 3) m,
  ]..sort((a, b) {
      final mood = (b.mood ?? 3).compareTo(a.mood ?? 3);
      return mood != 0 ? mood : b.text.trim().length.compareTo(a.text.trim().length);
    });
  return worth.take(max).toList();
}
