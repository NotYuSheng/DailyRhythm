import '../../journal/data/models/journal_entry.dart';
import 'garden_day.dart';
import 'plant.dart';

/// A month in review, from its garden days, day logs and moments: what
/// grew and what the days held. The month's numbers are in Metrics.
class MonthRecap {
  MonthRecap._({
    required this.month,
    required this.days,
    required this.plants,
    required this.quietDays,
    required this.species,
    required this.topActivities,
    required this.momentCount,
    required this.highlights,
  });

  final DateTime month;

  /// Days of the month so far (all of them for a past month).
  final List<GardenDay> days;
  final int plants;
  final int quietDays;

  /// Plants by species, most first.
  final List<(PlantSpecies, int)> species;

  /// Activity tags by days used, most first (up to five).
  final List<(String, int)> topActivities;
  final int momentCount;

  /// Moments worth seeing again: good moods first, then ones with the most
  /// to say (up to three, with words, leaving out bad and awful ones).
  final List<JournalEntry> highlights;

  bool get isEmpty => plants == 0;

  /// [logs] and [days] cover the same dates; days after [today] are left
  /// out so a month in progress counts only what has happened.
  factory MonthRecap.from({
    required DateTime month,
    required List<DayLog> logs,
    required List<JournalEntry> moments,
    required Set<String> activityTags,
    DateTime? today,
  }) {
    final end = today ?? DateTime.now();
    final past = [for (final l in logs) if (!l.date.isAfter(end)) l];
    final pastMoments = [for (final m in moments) if (!m.date.isAfter(end)) m];
    final days = [for (final l in past) GardenDay.from(l)];
    final grown = [for (final d in days) if (d.plant.logged) d];

    final bySpecies = <PlantSpecies, int>{};
    for (final d in grown) {
      bySpecies[d.plant.species] = (bySpecies[d.plant.species] ?? 0) + 1;
    }
    final tagDays = <String, int>{};
    for (final l in past) {
      for (final t in l.tagNames.toSet()) {
        if (activityTags.contains(t)) tagDays[t] = (tagDays[t] ?? 0) + 1;
      }
    }
    // A moment without a mood counts as neutral.
    final highlights = [
      for (final m in pastMoments)
        if (m.text.trim().isNotEmpty && (m.mood ?? 3) >= 3) m,
    ]..sort((a, b) {
        final mood = (b.mood ?? 3).compareTo(a.mood ?? 3);
        return mood != 0 ? mood : b.text.trim().length.compareTo(a.text.trim().length);
      });

    return MonthRecap._(
      month: DateTime(month.year, month.month),
      days: days,
      plants: grown.length,
      quietDays: days.length - grown.length,
      species: rankByCount(bySpecies),
      topActivities: rankByCount(tagDays).take(5).toList(),
      momentCount: pastMoments.length,
      highlights: highlights.take(3).toList(),
    );
  }
}

/// Entries of [counts] as pairs, largest count first.
List<(K, int)> rankByCount<K>(Map<K, int> counts) =>
    [for (final e in counts.entries) (e.key, e.value)]..sort((a, b) => b.$2.compareTo(a.$2));
