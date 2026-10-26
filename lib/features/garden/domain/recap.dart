import '../../journal/data/models/journal_entry.dart';
import 'garden_day.dart';
import 'plant.dart';

/// A month in review, from its garden days, day logs and moments. Facts
/// describe what was logged, never what it means or what to do.
class MonthRecap {
  MonthRecap._({
    required this.month,
    required this.days,
    required this.plants,
    required this.flowers,
    required this.quietDays,
    required this.species,
    required this.topActivities,
    required this.sleepShortest,
    required this.sleepLongest,
    required this.sleepAverage,
    required this.moveSessions,
    required this.movingDays,
    required this.momentCount,
    required this.highlights,
  });

  final DateTime month;

  /// Days of the month so far (all of them for a past month).
  final List<GardenDay> days;
  final int plants;
  final int flowers;
  final int quietDays;

  /// Plants by species, most first.
  final List<(PlantSpecies, int)> species;

  /// Activity tags by days used, most first (up to five).
  final List<(String, int)> topActivities;
  final double? sleepShortest;
  final double? sleepLongest;
  final double? sleepAverage;
  final int moveSessions;
  final int movingDays;
  final int momentCount;

  /// Moments worth seeing again: good moods first, then ones with the most
  /// to say (up to three, with words).
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
    final sleeps = [for (final l in past) if (l.sleepHours != null) l.sleepHours!];
    final withWords = [for (final m in moments) if (m.text.trim().isNotEmpty) m];
    final highlights = [...withWords]..sort((a, b) {
        final mood = (b.mood ?? 0).compareTo(a.mood ?? 0);
        return mood != 0 ? mood : b.text.length.compareTo(a.text.length);
      });

    List<(K, int)> ranked<K>(Map<K, int> counts) =>
        [for (final e in counts.entries) (e.key, e.value)]..sort((a, b) => b.$2.compareTo(a.$2));

    return MonthRecap._(
      month: DateTime(month.year, month.month),
      days: days,
      plants: grown.length,
      flowers: grown.where((d) => d.plant.flower).length,
      quietDays: days.length - grown.length,
      species: ranked(bySpecies),
      topActivities: ranked(tagDays).take(5).toList(),
      sleepShortest: sleeps.isEmpty ? null : sleeps.reduce((a, b) => a < b ? a : b),
      sleepLongest: sleeps.isEmpty ? null : sleeps.reduce((a, b) => a > b ? a : b),
      sleepAverage: sleeps.isEmpty ? null : sleeps.reduce((a, b) => a + b) / sleeps.length,
      moveSessions: days.fold(0, (sum, d) => sum + d.moveCount),
      movingDays: days.where((d) => d.moveCount > 0).length,
      momentCount: moments.length,
      highlights: highlights.take(3).toList(),
    );
  }
}

/// A year in review: twelve small gardens and a few facts across them.
class YearRecap {
  YearRecap(this.year, this.months);

  final int year;

  /// Every month of the year up to now, in order.
  final List<MonthRecap> months;

  int get plants => months.fold(0, (sum, m) => sum + m.plants);
  int get flowers => months.fold(0, (sum, m) => sum + m.flowers);

  MonthRecap? _most(int Function(MonthRecap m) value) {
    final ranked = [for (final m in months) if (value(m) > 0) m]..sort((a, b) => value(b).compareTo(value(a)));
    return ranked.firstOrNull;
  }

  /// The month with the most movement sessions.
  MonthRecap? get mostActive => _most((m) => m.moveSessions);

  /// The month with the most moments written.
  MonthRecap? get mostMoments => _most((m) => m.momentCount);

  /// The month with the most flowers.
  MonthRecap? get mostFlowers => _most((m) => m.flowers);

  /// The plant grown most across the year.
  (PlantSpecies, int)? get topSpecies {
    final counts = <PlantSpecies, int>{};
    for (final m in months) {
      for (final (s, n) in m.species) {
        counts[s] = (counts[s] ?? 0) + n;
      }
    }
    final ranked = [for (final e in counts.entries) (e.key, e.value)]..sort((a, b) => b.$2.compareTo(a.$2));
    return ranked.firstOrNull;
  }
}
