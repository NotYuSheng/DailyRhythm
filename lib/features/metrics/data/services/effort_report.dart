import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/utils/date_utils.dart';
import '../../../garden/data/garden_repository.dart';
import '../../../garden/domain/garden_day.dart';
import '../../presentation/widgets/garden_scene_card.dart';
import '../models/metric_data.dart';

/// How hard a period's exercise days were: how many at each effort level
/// (1 Light … 5 Very hard), the usual level, which weekdays are hardest,
/// and how often you exercised against the period before.
class EffortReport {
  const EffortReport({
    required this.byLevel,
    required this.days,
    required this.byWeekday,
    this.perWeek,
    this.previousPerWeek,
  });

  /// Exercise days at each level, Light first (5 counts).
  final List<int> byLevel;

  /// Days in the period.
  final int days;

  /// Average effort on each weekday's exercise days, Monday first; null
  /// for a weekday without any.
  final List<double?> byWeekday;

  /// Exercise days a week, this period and the one before (null for all
  /// time, or with nothing logged before).
  final double? perWeek;
  final double? previousPerWeek;

  int get exerciseDays => byLevel.fold(0, (a, b) => a + b);

  /// Hard or Very hard.
  int get hardDays => byLevel[3] + byLevel[4];

  /// The middle level of the exercise days (1–5), or null without any.
  int? get usual {
    if (exerciseDays == 0) return null;
    var seen = 0;
    for (var i = 0; i < 5; i++) {
      seen += byLevel[i];
      if (seen * 2 >= exerciseDays) return i + 1;
    }
    return 5;
  }

  /// The weekday (1 Monday … 7 Sunday) with the hardest average, when at
  /// least two weekdays have exercise to compare.
  int? get hardestWeekday {
    final known = [for (var i = 0; i < 7; i++) if (byWeekday[i] != null) (i + 1, byWeekday[i]!)];
    if (known.length < 2) return null;
    known.sort((a, b) => b.$2.compareTo(a.$2));
    return known.first.$2 > known.last.$2 ? known.first.$1 : null;
  }

  static EffortReport from(List<GardenDay> days, {List<GardenDay>? previous, int? previousLength}) {
    final byLevel = List.filled(5, 0);
    final sums = List.filled(7, 0.0), counts = List.filled(7, 0);
    for (final d in days) {
      final e = d.effort;
      if (e == null) continue;
      byLevel[(e - 1).clamp(0, 4)]++;
      sums[d.date.weekday - 1] += e;
      counts[d.date.weekday - 1]++;
    }
    double? rate(Iterable<GardenDay> list, int length) =>
        length <= 0 ? null : list.where((d) => d.effort != null).length / length * 7;
    final prior = previous == null || previousLength == null || !previous.any((d) => d.plant.logged) ? null : rate(previous, previousLength);
    return EffortReport(
      byLevel: byLevel,
      days: days.length,
      byWeekday: [for (var i = 0; i < 7; i++) counts[i] == 0 ? null : sums[i] / counts[i]],
      perWeek: prior == null ? null : rate(days, days.length),
      previousPerWeek: prior,
    );
  }
}

/// The calendar period before [range], of the same kind (week, month or
/// year); null for all time.
DateRange? previousPeriod(DateRange range) {
  if (range.isAllTime) return null;
  final before = DateTime(range.start.year, range.start.month, range.start.day - 1);
  // The labels say which kind it is: "2026", "3–9 Nov" or "November 2026".
  if (range.label == '${range.start.year}') return DateRange.year(before);
  if (range.label.contains('–')) return DateRange.week(before);
  return DateRange.month(before);
}

final effortReportProvider = FutureProvider.autoDispose.family<EffortReport, DateRange>((ref, range) async {
  final days = await ref.watch(periodGardenProvider(range).future);
  final before = previousPeriod(range);
  if (before == null) return EffortReport.from(days);
  final previous = await GardenRepository(ref.watch(databaseProvider)).daysInRange(dayOf(before.start), dayOf(before.end));
  return EffortReport.from(days, previous: previous, previousLength: previous.length);
});
