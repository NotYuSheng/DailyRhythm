import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/utils/date_utils.dart';
import '../../../garden/data/garden_repository.dart';
import '../../../garden/data/plant_style_provider.dart';
import '../../../garden/domain/garden_day.dart';
import '../../../garden/domain/garden_scene.dart';
import '../../../garden/domain/plant.dart';
import '../../../garden/presentation/garden_style.dart';
import '../../../garden/presentation/screens/garden_month_screen.dart';
import '../../../garden/presentation/screens/year_gardens_screen.dart';
import '../../data/models/metric_data.dart';
import '../../data/services/level_report.dart' show previousPeriod, previousWord;
import 'garden_motion.dart';

/// Every day of a period, all time from the first entry.
final periodGardenProvider = FutureProvider.autoDispose.family<List<GardenDay>, DateRange>((ref, range) async {
  final db = ref.watch(databaseProvider);
  final first = range.isAllTime ? await db.firstLoggedDay() : null;
  return GardenRepository(db).daysInRange(dayOf(first ?? range.start), dayOf(range.end));
});

/// The period's plants at a glance: hills whose sky follows the season,
/// golden hour for a year, night in dark mode. Tapping opens the calendar.
class GardenSceneCard extends ConsumerWidget {
  const GardenSceneCard({super.key, required this.range});

  final DateRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);
    final days = ref.watch(periodGardenProvider(range)).value;
    final before = previousPeriod(range);
    final previous = before == null ? null : ref.watch(periodGardenProvider(before)).value;
    final style = ref.watch(plantStyleProvider);
    final plants = [for (final d in days ?? const <GardenDay>[]) if (d.plant.logged) d.plant];
    final look = SceneLook.forPeriod(days?.first.date ?? range.start, range.end, dark: Theme.of(context).brightness == Brightness.dark);
    final shown = GardenScene.sample(plants).length;
    final seed = range.start.millisecondsSinceEpoch ~/ 86400000;
    final title = range.isAllTime
        ? 'Your whole garden'
        : range.end.difference(range.start).inDays > 31
            ? '${range.start.year}’s garden'
            : range.end.difference(range.start).inDays > 7
                ? '${DateFormat('MMMM').format(range.start)}’s garden'
                : 'This week’s garden';

    void open() {
      final yearLong = range.isAllTime || range.end.difference(range.start).inDays > 31;
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => yearLong ? YearGardensScreen(year: range.end.year) : GardenMonthScreen(month: DateTime(range.end.year, range.end.month)),
        ),
      );
    }

    return Semantics(
      button: true,
      label: '$title: ${caption(days ?? const [], previous, range, shown: shown)}. ${look.label}. Opens the calendar.',
      excludeSemantics: true,
      child: Material(
        color: colors.card,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(title, style: nunito(18, FontWeight.w900, colors.ink))),
                      Text('Calendar ›', style: nunito(14, FontWeight.w800, colors.accent)),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: GardenScene.width / GardenScene.height,
                    child: days == null
                        ? ColoredBox(color: colors.ground)
                        // Gently moving, unless the system asks for less motion.
                        : MediaQuery.disableAnimationsOf(context)
                            ? SvgPicture.string(GardenScene.svg(plants, look, seed: seed, style: style), fit: BoxFit.cover)
                            : GardenMotion(
                                key: ValueKey((look, seed, style, plants.length)),
                                layers: GardenScene.layers(plants, look, seed: seed, style: style, weather: false),
                                look: look,
                                seed: seed,
                              ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
                  child: Text(caption(days ?? const [], previous, range, shown: shown), style: nunito(14, FontWeight.w700, colors.ink)),
                ),
                if (plants.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
                    child: _DayKinds(counts: _counts(plants), total: plants.length, colors: colors),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// What's worth noticing in the period's garden, the kinds of day being
  /// listed below it: how much of the period was logged, then the most
  /// telling thing about it. That's a clear change from the period before,
  /// else a run of the same kind of day, else the kind there was most of.
  static String caption(List<GardenDay> days, List<GardenDay>? previous, DateRange range, {int? shown}) {
    final grown = [for (final d in days) if (d.plant.logged) d];
    if (grown.isEmpty) return 'Nothing grew in this period yet.';
    final number = NumberFormat.decimalPattern();
    final logged = range.isAllTime
        ? '${number.format(grown.length)} ${grown.length == 1 ? 'day' : 'days'} logged since ${DateFormat('MMM y').format(grown.first.date)}'
        : '${grown.length} of ${days.length} ${days.length == 1 ? 'day' : 'days'} logged';
    final sampled = shown != null && shown < grown.length ? ' (showing $shown in the same mix)' : '';
    return '$logged$sampled. ${_notable(grown, previous, range)}.';
  }

  static String _notable(List<GardenDay> grown, List<GardenDay>? previous, DateRange range) {
    String capital(String s) => '${s[0].toUpperCase()}${s.substring(1)}';
    // A kind whose share of the logged days moved a lot against the period
    // before (not the catch-all sprout): shares, so a month still under way
    // compares fairly with a whole one.
    final before = [for (final d in previous ?? const <GardenDay>[]) if (d.plant.logged) d];
    if (before.length >= 5 && !range.isAllTime) {
      double share(List<GardenDay> list, PlantSpecies s) => list.where((d) => d.plant.species == s).length / list.length;
      (PlantSpecies, double, double)? best;
      for (final s in PlantSpecies.values) {
        if (s == PlantSpecies.sprout) continue;
        final now = share(grown, s), was = share(before, s);
        final enough = grown.where((d) => d.plant.species == s).length >= 3 || before.where((d) => d.plant.species == s).length >= 3;
        if (enough && (now - was).abs() >= 0.2 && (best == null || (now - was).abs() > (best.$2 - best.$3).abs())) best = (s, now, was);
      }
      if (best case (final s, final now, final was)) {
        String pc(double v) => '${(v * 100).round()}%';
        return '${now > was ? 'More' : 'Fewer'} ${s.daysWord} than ${previousWord(range)}: ${pc(now)} of days, ${now > was ? 'up' : 'down'} from ${pc(was)}';
      }
    }
    // The longest run of one kind of day (sprouts aside), when 3 or more.
    (PlantSpecies, DateTime, DateTime, int)? run;
    PlantSpecies? kind;
    DateTime? start, last;
    var length = 0;
    for (final d in grown) {
      final continues = kind == d.plant.species && last != null && daysBetween(last, d.date) == 1;
      if (continues) {
        length++;
      } else {
        kind = d.plant.species;
        start = d.date;
        length = 1;
      }
      last = d.date;
      if (kind != PlantSpecies.sprout && length >= 3 && (run == null || length > run.$4)) run = (kind!, start!, d.date, length);
    }
    if (run case (final s, final from, final to, final n)) {
      final span = from.month == to.month ? '${from.day}–${DateFormat('d MMM').format(to)}' : '${DateFormat('d MMM').format(from)} – ${DateFormat('d MMM').format(to)}';
      return '$n ${s.daysWord} in a row, $span';
    }
    final top = _counts([for (final d in grown) d.plant]).take(2).map((e) => e.key.daysWord).toList();
    return grown.length == 1 ? capital(grown.single.plant.species.dayWord) : 'Mostly ${top.join(' and ')}';
  }

  /// Each kind of day and how many, most first.
  static List<MapEntry<PlantSpecies, int>> _counts(List<PlantSpec> plants) {
    final counts = <PlantSpecies, int>{};
    for (final p in plants) {
      counts[p.species] = (counts[p.species] ?? 0) + 1;
    }
    return counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }
}

/// Every kind of day the garden grew, with how many and its share: what
/// each plant stands for, without opening the calendar.
class _DayKinds extends StatelessWidget {
  const _DayKinds({required this.counts, required this.total, required this.colors});

  final List<MapEntry<PlantSpecies, int>> counts;
  final int total;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final MapEntry(key: kind, value: n) in counts)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: colors.bed, borderRadius: BorderRadius.circular(12)),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '${kind.label} ', style: nunito(13, FontWeight.w800, colors.ink)),
                TextSpan(text: '$n · ${(n / total * 100).round()}%', style: nunito(13, FontWeight.w700, colors.muted)),
              ]),
            ),
          ),
      ],
    );
  }
}
