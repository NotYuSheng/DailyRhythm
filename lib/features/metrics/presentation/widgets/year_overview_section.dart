import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../garden/presentation/garden_style.dart';
import '../../data/models/year_overview.dart';
import '../../data/providers/metrics_providers.dart';

/// What colours the year in pixels.
enum YearMetric {
  sleep('Sleep', ['Under 5h', '5–6h', '6–7h', '7–8h', '8h+'], [0xFFE3E1FA, 0xFFB9B3F2, 0xFF8A80E3, 0xFF5B4FC9, 0xFF372C9A]),
  steps('Steps', ['Under 3k', '3–6k', '6–9k', '9–12k', '12k+'], [0xFFDDF1E4, 0xFFA9DDB8, 0xFF6CC08A, 0xFF3F9A62, 0xFF1F6B45]),
  calories('Calories', ['Under 1.6k', '1.6–1.9k', '1.9–2.2k', '2.2–2.5k', '2.5k+'], [0xFFFFF4D6, 0xFFFCE1A4, 0xFFF6C063, 0xFFE59A2F, 0xFFB86E12]),
  mood('Mood', ['Awful', 'Bad', 'Okay', 'Good', 'Great'], [0xFFC2410C, 0xFFF59E0B, 0xFFDCE6E0, 0xFF7FCB96, 0xFF1F6B45]),
  energy('Energy', ['Much lower', 'Lower', 'Usual', 'Higher', 'Much higher'], [0xFFF59E0B, 0xFFFBD38D, 0xFFDCE6E0, 0xFF8EC9F0, 0xFF2B6CB0]);

  const YearMetric(this.label, this.levels, this.colors);

  final String label;
  final List<String> levels;
  final List<int> colors;

  /// The level (0–4) a day falls in, or null without a value.
  int? levelOf(DayValues d) => switch (this) {
        sleep => _band(d.sleepHours, const [5, 6, 7, 8]),
        steps => _band(d.steps, const [3000, 6000, 9000, 12000]),
        calories => _band(d.kcal, const [1600, 1900, 2200, 2500]),
        mood => d.mood == null ? null : (d.mood! - 1).clamp(0, 4),
        energy => d.energy == null ? null : (d.energy! + 2).clamp(0, 4),
      };

  static int? _band(double? v, List<num> cuts) {
    if (v == null) return null;
    var i = 0;
    while (i < cuts.length && v >= cuts[i]) {
      i++;
    }
    return i;
  }
}

const _letters = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

/// Metrics for a year: every day coloured by a chosen measure, mood and
/// sleep by month, the tags that stood out, and a row per month.
class YearOverviewSection extends ConsumerStatefulWidget {
  const YearOverviewSection({super.key, required this.year});

  final int year;

  @override
  ConsumerState<YearOverviewSection> createState() => _YearOverviewSectionState();
}

class _YearOverviewSectionState extends ConsumerState<YearOverviewSection> {
  YearMetric _metric = YearMetric.sleep;

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    return ref.watch(yearOverviewProvider(widget.year)).when(
          loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('Couldn’t load the year: $e'),
          data: (o) => !o.hasData
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GardenSection(
                      title: 'Every day of the year',
                      colors: colors,
                      child: _Pixels(overview: o, metric: _metric, colors: colors, onMetric: (m) => setState(() => _metric = m)),
                    ),
                    const SizedBox(height: 14),
                    GardenSection(title: 'Mood by month', colors: colors, child: _MoodByMonth(overview: o, colors: colors)),
                    if (o.sleepByMonth.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      GardenSection(
                        title: 'Your sleep, month by month',
                        subtitle: 'Bar: usual bedtime to usual waking. Pale ends: how much that moved.',
                        colors: colors,
                        child: _SleepByMonth(overview: o, colors: colors),
                      ),
                    ],
                    if (o.rareTags.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      GardenSection(
                        title: 'Days that stood out',
                        subtitle: o.everydayTags.isEmpty ? null : 'Left out, as they were on almost every day: ${o.everydayTags.join(', ')}.',
                        colors: colors,
                        child: _RareTags(overview: o, colors: colors),
                      ),
                    ],
                    const SizedBox(height: 14),
                    GardenSection(title: 'Month by month', colors: colors, child: _MonthTable(overview: o, colors: colors)),
                  ],
                ),
        );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color, this.label, this.colors);

  final Color color;
  final String label;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text(label, style: nunito(11, FontWeight.w800, colors.muted)),
        ],
      );
}

class _Pixels extends StatelessWidget {
  const _Pixels({required this.overview, required this.metric, required this.colors, required this.onMetric});

  final YearOverview overview;
  final YearMetric metric;
  final GardenColors colors;
  final ValueChanged<YearMetric> onMetric;

  @override
  Widget build(BuildContext context) {
    final byMonth = <int, Map<int, DayValues>>{};
    for (final d in overview.days) {
      (byMonth[d.date.month] ??= {})[d.date.day] = d;
    }
    final withValue = overview.days.where((d) => metric.levelOf(d) != null).length;
    final empty = colors.bed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in YearMetric.values)
              ChoiceChip(label: Text(m.label), selected: m == metric, onSelected: (_) => onMetric(m)),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          label: 'Each day of ${overview.year} coloured by ${metric.label.toLowerCase()}; $withValue days have a value.',
          excludeSemantics: true,
          child: Column(
            children: [
              for (var m = 1; m <= 12; m++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      SizedBox(width: 14, child: Text(_letters[m - 1], style: nunito(10, FontWeight.w800, colors.muted))),
                      for (var day = 1; day <= 31; day++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: switch (byMonth[m]?[day]) {
                                    null => Colors.transparent,
                                    final d => switch (metric.levelOf(d)) {
                                        final level? => Color(metric.colors[level]),
                                        null => empty,
                                      },
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [for (var i = 0; i < 5; i++) _Swatch(Color(metric.colors[i]), metric.levels[i], colors)],
        ),
        if (withValue == 0) ...[
          const SizedBox(height: 6),
          Text('No ${metric.label.toLowerCase()} logged this year.', style: nunito(13, FontWeight.w700, colors.muted)),
        ],
      ],
    );
  }
}

class _MoodByMonth extends StatelessWidget {
  const _MoodByMonth({required this.overview, required this.colors});

  final YearOverview overview;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    final palette = YearMetric.mood.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var m = 0; m < 12; m++)
                Expanded(
                  child: Semantics(
                    label: '${DateFormat('MMMM').format(DateTime(2000, m + 1))}: '
                        '${[for (var l = 0; l < 5; l++) if (overview.moodByMonth[m][l] > 0) '${YearMetric.mood.levels[l]} ${overview.moodByMonth[m][l]}'].join(', ')}',
                    excludeSemantics: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: ColoredBox(
                                color: colors.ground,
                                child: Column(
                                  verticalDirection: VerticalDirection.up,
                                  children: [
                                    for (var l = 0; l < 5; l++)
                                      if (overview.moodByMonth[m][l] > 0)
                                        Expanded(flex: overview.moodByMonth[m][l], child: ColoredBox(color: Color(palette[l]), child: const SizedBox.expand())),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(_letters[m], style: nunito(10, FontWeight.w800, colors.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 4, children: [for (var l = 0; l < 5; l++) _Swatch(Color(palette[l]), YearMetric.mood.levels[l], colors)]),
      ],
    );
  }
}

class _SleepByMonth extends StatelessWidget {
  const _SleepByMonth({required this.overview, required this.colors});

  final YearOverview overview;
  final GardenColors colors;

  static String clock(double hoursAfter6pm) {
    final minutes = ((hoursAfter6pm + 18) * 60 / 5).round() * 5 % (24 * 60);
    return '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final shortest = [for (final m in overview.sleepByMonth) ?m.hours].fold<double?>(null, (a, b) => a == null || b < a ? b : a);
    const night = Color(0xFF5B4FC9);
    const spread = Color(0xFFC9C3F5);
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 34),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => SizedBox(
                  height: 14,
                  child: Stack(
                    children: [
                      for (final (i, label) in ['18:00', '23:00', '04:00', '09:00', '14:00'].indexed)
                        Positioned(
                          left: (box.maxWidth * i / 4 - (i == 0 ? 0 : i == 4 ? 30 : 15)).clamp(0, box.maxWidth - 30),
                          child: Text(label, style: nunito(10, FontWeight.w800, colors.muted)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 44),
          ],
        ),
        const SizedBox(height: 4),
        for (final m in overview.sleepByMonth)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Semantics(
              label: '${DateFormat('MMMM').format(DateTime(2000, m.month))}: usually asleep ${clock(m.bed)} to ${clock(m.wake)}'
                  '${m.hours == null ? '' : ', ${m.hours!.toStringAsFixed(1)} hours on average'}',
              excludeSemantics: true,
              child: Row(
                children: [
                  SizedBox(width: 34, child: Text(DateFormat('MMM').format(DateTime(2000, m.month)), style: nunito(12, FontWeight.w900, colors.ink))),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        double x(double h) => box.maxWidth * h.clamp(0, NightSpan.span) / NightSpan.span;
                        Widget bar(double from, double to, Color color, double height) => Positioned(
                              left: x(from),
                              width: (x(to) - x(from)).clamp(2, box.maxWidth),
                              top: (20 - height) / 2,
                              height: height,
                              child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2))),
                            );
                        return Container(
                          height: 20,
                          decoration: BoxDecoration(color: colors.ground, borderRadius: BorderRadius.circular(6)),
                          child: Stack(
                            children: [
                              bar(m.bedLow, m.bedHigh, spread, 10),
                              bar(m.wakeLow, m.wakeHigh, spread, 10),
                              bar(m.bed, m.wake, night, 12),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      m.hours == null ? '' : '${m.hours!.toStringAsFixed(1)}h',
                      textAlign: TextAlign.right,
                      style: nunito(12, m.hours == shortest ? FontWeight.w900 : FontWeight.w700, colors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RareTags extends StatelessWidget {
  const _RareTags({required this.overview, required this.colors});

  final YearOverview overview;
  final GardenColors colors;

  static const _palette = [Color(0xFF2F7D4C), Color(0xFFD9467A), Color(0xFFB7791F), Color(0xFF6B46C1), Color(0xFF2B6CB0)];

  @override
  Widget build(BuildContext context) {
    final start = DateTime(overview.year);
    final length = DateTime(overview.year + 1).difference(start).inDays;
    return Column(
      children: [
        for (final (i, tag) in overview.rareTags.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Semantics(
              label: '${tag.name} on ${tag.days.length} days',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(tag.name, style: nunito(13, FontWeight.w800, colors.ink))),
                      Text('${tag.days.length} ${tag.days.length == 1 ? 'day' : 'days'}', style: nunito(13, FontWeight.w800, colors.muted)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  LayoutBuilder(
                    builder: (context, box) => Container(
                      height: 14,
                      decoration: BoxDecoration(color: colors.ground, borderRadius: BorderRadius.circular(7)),
                      child: Stack(
                        children: [
                          for (final d in tag.days)
                            Positioned(
                              left: ((box.maxWidth - 8) * d.difference(start).inDays / length),
                              top: 3,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: _palette[i % _palette.length], shape: BoxShape.circle),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthTable extends StatelessWidget {
  const _MonthTable({required this.overview, required this.colors});

  final YearOverview overview;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    final rows = overview.months;
    double? best(double? Function(MonthRow) f) => [for (final r in rows) ?f(r)].fold<double?>(null, (a, b) => a == null || b > a ? b : a);
    final bestSleep = best((r) => r.sleep);
    final bestSteps = best((r) => r.steps);
    // Spending is SGD, shown as dollars like everywhere else in the app.
    final whole = NumberFormat('#,##0');
    String money(double v) => '\$${whole.format(v.round())}';
    Widget cell(String text, {bool bold = false, bool header = false}) => Expanded(
          child: Text(
            text,
            style: nunito(header ? 11 : 13, header || bold ? FontWeight.w900 : FontWeight.w700, header ? colors.muted : colors.ink),
          ),
        );
    String k(double? v) => v == null ? '–' : '${(v / 1000).toStringAsFixed(1)}k';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [const SizedBox(width: 38), cell('Sleep', header: true), cell('Steps', header: true), cell('Kcal/day', header: true), cell('Food', header: true), cell('Events', header: true)]),
        const Divider(height: 10),
        for (final r in rows)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 30),
            child: Row(
              children: [
                SizedBox(width: 38, child: Text(DateFormat('MMM').format(DateTime(2000, r.month)), style: nunito(13, FontWeight.w900, colors.ink))),
                cell(r.sleep == null ? '–' : '${r.sleep!.toStringAsFixed(1)}h', bold: r.sleep != null && r.sleep == bestSleep),
                cell(k(r.steps), bold: r.steps != null && r.steps == bestSteps),
                cell(k(r.kcal)),
                cell(r.food == 0 ? '–' : money(r.food)),
                cell(r.events == 0 ? '–' : money(r.events)),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text('Bold: the year’s best month. Calories are estimates.', style: nunito(12, FontWeight.w700, colors.muted)),
      ],
    );
  }
}
