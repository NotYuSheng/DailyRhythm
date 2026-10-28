import 'garden_day.dart';
import 'plant.dart';

/// A few neutral facts about a year of gardens: the fullest month, the
/// plant that grew most, and the quiet days. What was logged, never what
/// it means.
class YearFacts {
  const YearFacts({required this.plants, required this.quietDays, this.fullestMonth, this.fullestCount = 0, this.commonest, this.commonestCount = 0});

  final int plants;
  final int quietDays;

  /// The month with the most plants (the earliest on a tie).
  final DateTime? fullestMonth;
  final int fullestCount;
  final PlantSpecies? commonest;
  final int commonestCount;

  factory YearFacts.from(List<GardenDay> days) {
    final grown = [for (final d in days) if (d.plant.logged) d];
    final perMonth = <DateTime, int>{};
    final perSpecies = <PlantSpecies, int>{};
    for (final d in grown) {
      final month = DateTime(d.date.year, d.date.month);
      perMonth[month] = (perMonth[month] ?? 0) + 1;
      perSpecies[d.plant.species] = (perSpecies[d.plant.species] ?? 0) + 1;
    }
    MapEntry<K, int>? most<K>(Map<K, int> counts) =>
        counts.entries.fold<MapEntry<K, int>?>(null, (best, e) => best == null || e.value > best.value ? e : best);
    final month = most(perMonth);
    final species = most(perSpecies);
    return YearFacts(
      plants: grown.length,
      quietDays: days.length - grown.length,
      fullestMonth: month?.key,
      fullestCount: month?.value ?? 0,
      commonest: species?.key,
      commonestCount: species?.value ?? 0,
    );
  }
}
