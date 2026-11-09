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
                        : SvgPicture.string(
                            GardenScene.svg(plants, look, seed: range.start.millisecondsSinceEpoch ~/ 86400000, style: style),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
                  child: Text(_caption(plants, shown), style: nunito(14, FontWeight.w700, colors.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _caption(List<PlantSpec> plants, int shown) {
    if (plants.isEmpty) return 'Nothing grew in this period yet.';
    // Named as they grew: a kind's plant in the season it was most grown.
    final counts = <PlantSpecies, int>{};
    final seasons = <PlantSpecies, Map<Season, int>>{};
    for (final p in plants) {
      counts[p.species] = (counts[p.species] ?? 0) + 1;
      final bySeason = seasons.putIfAbsent(p.species, () => {});
      bySeason[p.season] = (bySeason[p.season] ?? 0) + 1;
    }
    Season mainSeason(PlantSpecies s) => (seasons[s]!.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    final top = (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(2).map((e) => e.key.pluralIn(mainSeason(e.key)));
    final mostly = plants.length == 1 ? 'a ${plants.single.name}' : 'mostly ${top.join(' and ')}';
    return '${plants.length} ${plants.length == 1 ? 'plant' : 'plants'}, $mostly'
        '${shown < plants.length ? ' · showing $shown in the same mix' : ''}';
  }
}
