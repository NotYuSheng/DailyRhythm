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
      label: '$title: ${_caption(plants, shown)}. ${look.label}. Opens the calendar.',
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
                  child: Text(_caption(plants, shown), style: nunito(14, FontWeight.w700, colors.ink)),
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

  /// What the garden says about the days: how many grew a plant, and the
  /// kinds of day there were most of.
  static String _caption(List<PlantSpec> plants, int shown) {
    if (plants.isEmpty) return 'Nothing grew in this period yet.';
    final top = _counts(plants).take(2).map((e) => e.key.daysWord).toList();
    final days = '${plants.length} ${plants.length == 1 ? 'day' : 'days'} grew a plant';
    final mostly = plants.length == 1 ? 'a ${plants.single.species.dayWord}' : 'mostly ${top.join(' and ')}';
    return '$days: $mostly'
        '${shown < plants.length ? ' (showing $shown in the same mix)' : ''}.';
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
