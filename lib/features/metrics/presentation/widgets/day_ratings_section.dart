import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../garden/presentation/garden_style.dart';
import '../../data/models/metric_data.dart';
import '../../data/providers/metrics_providers.dart';
import '../../data/services/day_ratings_service.dart';

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
          GardenSection(
            title: 'How days went',
            subtitle: 'Mood, and energy, stress and focus compared with a usual day',
            colors: colors,
            child: r.summaries.every((s) => s.days == 0)
                ? Text('Rate a day on the Today page to see this.', style: nunito(14, FontWeight.w600, colors.muted))
                : Column(children: [for (final s in r.summaries) if (s.days > 0) _RatingRow(summary: s, colors: colors)]),
          ),
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

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.summary, required this.colors});

  final RatingSummary summary;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    final rating = summary.rating;
    final average = summary.average!;
    final previous = summary.previousAverage;
    final change = previous == null || summary.days < DayRatingsService.minDays || (average - previous).abs() < 0.3
        ? ''
        : ', ${average > previous ? 'higher' : 'lower'} than the period before';
    final values = [for (var v = rating.min; v <= rating.max; v++) v];
    // Low to high: pale to deep leaf.
    final shades = [for (var i = 0; i < values.length; i++) Color.lerp(colors.bed, colors.leaf, i / (values.length - 1))!];

    return Semantics(
      container: true,
      label: '${rating.label}: mostly ${rating.wordFor(summary.mostCommon).toLowerCase()} over ${summary.days} days$change. '
          '${[for (final v in values) if (summary.counts[v]! > 0) '${rating.wordFor(v)} ${summary.counts[v]}'].join(', ')}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(rating.label, style: nunito(15, FontWeight.w900, colors.ink)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'mostly ${rating.wordFor(summary.mostCommon).toLowerCase()} · ${summary.days} ${summary.days == 1 ? 'day' : 'days'}$change',
                    style: nunito(13, FontWeight.w600, colors.muted),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    for (final (i, v) in values.indexed)
                      if (summary.counts[v]! > 0) Expanded(flex: summary.counts[v]!, child: ColoredBox(color: shades[i], child: const SizedBox.expand())),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(rating.words.first, style: nunito(11, FontWeight.w700, colors.muted)),
                Text(rating.words.last, style: nunito(11, FontWeight.w700, colors.muted)),
              ],
            ),
          ],
        ),
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
