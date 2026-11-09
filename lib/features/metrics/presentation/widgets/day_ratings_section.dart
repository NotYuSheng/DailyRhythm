import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../garden/presentation/garden_style.dart';
import '../../data/models/metric_data.dart';
import '../../data/providers/metrics_providers.dart';
import '../../data/services/day_ratings_service.dart';
import 'level_sections.dart';

/// How days went (mood, energy, stress, focus), how that differed on days
/// with each tag, and the watch's averages, as garden cards.
class DayRatingsSection extends ConsumerWidget {
  const DayRatingsSection({super.key, required this.range});

  final DateRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);
    final report = ref.watch(dayRatingsProvider(range));
    return report.when(
      loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
      error: (_, _) => Text('Day ratings aren’t available right now.', style: nunito(14, FontWeight.w600, colors.muted)),
      data: (r) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mood, energy, stress and focus, in the same card as food and exercise.
          HowDaysWentSection(range: range),
          if (r.comparisons.isNotEmpty) ...[
            const SizedBox(height: 16),
            GardenSection(
              title: 'Days with and without',
              subtitle: 'What was rated, not what caused it',
              colors: colors,
              child: Column(
                children: [
                  for (final c in r.comparisons)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(c.difference > 0 ? Icons.north_east : Icons.south_east, size: 18, color: colors.leaf),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(c.text, style: nunito(14, FontWeight.w600, colors.ink))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (r.watch.isNotEmpty) ...[
            const SizedBox(height: 16),
            GardenSection(
              title: 'From your watch',
              subtitle: 'Daily averages',
              colors: colors,
              child: LayoutBuilder(
                builder: (context, box) {
                  final width = (box.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [for (final w in r.watch) SizedBox(width: width, child: _WatchTile(average: w, colors: colors))],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WatchTile extends StatelessWidget {
  const _WatchTile({required this.average, required this.colors});

  final WatchAverage average;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    final m = average.metric;
    String fmt(double v) => m == WatchMetric.sleep ? v.toStringAsFixed(1) : NumberFormat.decimalPattern().format(v.round());
    final previous = average.previousAverage;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colors.ground, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: nunito(12, FontWeight.w800, colors.leaf)),
          Text('${fmt(average.average)}${m.unit.isEmpty ? '' : ' ${m.unit}'}', style: nunito(20, FontWeight.w900, colors.ink)),
          Text(
            previous == null ? '${average.days} days' : 'Before: ${fmt(previous)}',
            style: nunito(12, FontWeight.w600, colors.muted),
          ),
        ],
      ),
    );
  }
}
