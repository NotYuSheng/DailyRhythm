import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/utils/date_utils.dart';
import '../../../garden/presentation/garden_style.dart';
import '../../data/models/metric_data.dart';
import '../../data/models/period_overview.dart';
import '../../data/providers/metrics_providers.dart';
import '../../../profile/data/profile_providers.dart';
import '../../../profile/domain/profile.dart';

/// What colours the days in the overview's grid.
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

  /// Calories either side of the user's range that count as well under or
  /// well over it.
  static const _kcalMargin = 400.0;

  /// The level (0–4) a day falls in, or null without a value. With the
  /// user's calorie range, calories are coloured against it: the middle
  /// level is the range itself.
  int? levelOf(DayValues d, {ValueRange? kcal}) => switch (this) {
        sleep => _band(d.sleepHours, const [5, 6, 7, 8]),
        steps => _band(d.steps, const [3000, 6000, 9000, 12000]),
        calories when kcal != null => _band(d.kcal, [kcal.low - _kcalMargin, kcal.low, kcal.high + 0.5, kcal.high + _kcalMargin]),
        calories => _band(d.kcal, const [1600, 1900, 2200, 2500]),
        mood => d.mood == null ? null : (d.mood! - 1).clamp(0, 4),
        energy => d.energy == null ? null : (d.energy! + 2).clamp(0, 4),
      };

  List<String> levelsFor(ValueRange? kcal) {
    if (this != calories || kcal == null) return levels;
    String k(double v) => '${(v / 1000).toStringAsFixed(1)}k';
    return [
      'Under ${k(kcal.low - _kcalMargin)}',
      '${k(kcal.low - _kcalMargin)}–${k(kcal.low)}',
      'Your range',
      '${k(kcal.high)}–${k(kcal.high + _kcalMargin)}',
      '${k(kcal.high + _kcalMargin)}+',
    ];
  }

  /// Against a range, under and over are different hues around a green middle.
  List<int> colorsFor(ValueRange? kcal) =>
      this == calories && kcal != null ? const [0xFFE59A2F, 0xFFFCE1A4, 0xFF7FCB96, 0xFFB5D8F2, 0xFF2B6CB0] : colors;

  static int? _band(double? v, List<num> cuts) {
    if (v == null) return null;
    var i = 0;
    while (i < cuts.length && v >= cuts[i]) {
      i++;
    }
    return i;
  }
}

/// Metrics for a period: every day coloured by a chosen measure, mood and
/// sleep by group (a week by day, a month by week, a year by month, all
/// time by year), the tags that stood out, and a row per group.
class PeriodOverviewSection extends ConsumerStatefulWidget {
  const PeriodOverviewSection({super.key, required this.scale, required this.range});

  final OverviewScale scale;
  final DateRange range;

  @override
  ConsumerState<PeriodOverviewSection> createState() => _PeriodOverviewSectionState();
}

class _PeriodOverviewSectionState extends ConsumerState<PeriodOverviewSection> {
  YearMetric _metric = YearMetric.sleep;

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    return ref.watch(periodOverviewProvider((widget.scale, widget.range))).when(
          loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('Couldn’t load the overview: $e'),
          data: (o) {
            if (!o.hasData) return const SizedBox.shrink();
            final scale = o.scale;
            final profile = ref.watch(profileProvider).value ?? const Profile();
            final today = DateTime.now();
            final sleepRange = PersonalRanges.sleepFor(profile.ageIn(today));
            final kcalRange = PersonalRanges.kcalFor(profile, today, averageSteps: o.averageSteps);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GardenSection(
                  title: switch (scale) {
                    OverviewScale.week => 'Every day of the week',
                    OverviewScale.month => 'Every day of the month',
                    OverviewScale.year => 'Every day of the year',
                    OverviewScale.all => 'Every week since you started',
                  },
                  colors: colors,
                  child: _Pixels(overview: o, metric: _metric, kcal: kcalRange, colors: colors, onMetric: (m) => setState(() => _metric = m)),
                ),
                if (o.moodByGroup.any((g) => g.any((n) => n > 0))) ...[
                  const SizedBox(height: 14),
                  GardenSection(title: 'Mood by ${scale.groupNoun}', colors: colors, child: _MoodByGroup(overview: o, colors: colors)),
                ],
                if (o.sleepByGroup.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  GardenSection(
                    title: 'Your sleep, ${scale.sleepTitle}',
                    subtitle: scale == OverviewScale.week
                        ? 'Bar: asleep to awake.'
                        : 'Bar: usual bedtime to usual waking. Pale ends: how much that moved.',
                    colors: colors,
                    child: _SleepByGroup(overview: o, colors: colors),
                  ),
                ],
                if (o.rareTags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  GardenSection(
                    title: scale == OverviewScale.week ? 'What the days held' : 'Days that stood out',
                    subtitle: o.everydayTags.isEmpty ? null : 'Left out, as they were on almost every day: ${o.everydayTags.join(', ')}.',
                    colors: colors,
                    child: _RareTags(overview: o, colors: colors),
                  ),
                ],
                const SizedBox(height: 14),
                GardenSection(title: scale.tableTitle, colors: colors, child: _Table(overview: o, sleepRange: sleepRange, kcalRange: kcalRange, profileSet: !profile.isEmpty, colors: colors)),
              ],
            );
          },
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
  const _Pixels({required this.overview, required this.metric, required this.kcal, required this.colors, required this.onMetric});

  final PeriodOverview overview;
  final YearMetric metric;
  final ValueRange? kcal;
  final GardenColors colors;
  final ValueChanged<YearMetric> onMetric;

  @override
  Widget build(BuildContext context) {
    int? levelOf(DayValues d) => metric.levelOf(d, kcal: kcal);
    final withValue = overview.cellsWith(levelOf);
    final palette = metric.colorsFor(kcal);
    final levels = metric.levelsFor(kcal);
    final columns = overview.grid.first.cells.length;
    // Dense grids (a year, all time) get thinner gaps and a row label.
    final gap = columns > 31 ? 1.0 : columns > 7 ? 2.0 : 4.0;
    final labelWidth = overview.grid.first.label.isEmpty ? 0.0 : (overview.scale == OverviewScale.all ? 22.0 : 14.0);
    final radius = columns > 7 ? 2.0 : 6.0;
    final unit = switch (overview.scale) {
      OverviewScale.week => 'week',
      OverviewScale.month => 'month',
      OverviewScale.year => 'year',
      OverviewScale.all => 'time',
    };
    Widget row(String label, List<Widget> cells) => Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: Row(
            children: [
              if (labelWidth > 0) SizedBox(width: labelWidth, child: Text(label, style: nunito(10, FontWeight.w800, colors.muted))),
              for (final c in cells) Expanded(child: Padding(padding: EdgeInsets.only(right: gap), child: c)),
            ],
          ),
        );
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
          label: '${overview.scale == OverviewScale.all ? 'Each week' : 'Each day'} coloured by ${metric.label.toLowerCase()}; $withValue have a value.',
          excludeSemantics: true,
          child: Column(
            children: [
              if (overview.columnLabels.isNotEmpty)
                row('', [
                  for (final l in overview.columnLabels) Text(l, textAlign: TextAlign.center, style: nunito(10, FontWeight.w800, colors.muted)),
                ]),
              for (final r in overview.grid)
                row(r.label, [
                  for (final cell in r.cells)
                    AspectRatio(
                      // 53 weeks a row are narrow: taller so they're seen.
                      aspectRatio: columns > 31 ? 0.4 : 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          color: switch (cell) {
                            null => Colors.transparent,
                            final d => switch (levelOf(d)) {
                                final level? => Color(palette[level]),
                                null => colors.bed,
                              },
                          },
                        ),
                      ),
                    ),
                ]),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [for (var i = 0; i < 5; i++) _Swatch(Color(palette[i]), levels[i], colors)],
        ),
        if (metric == YearMetric.calories) ...[
          const SizedBox(height: 4),
          Text(
            'Only days with ${PeriodOverview.completeDayMeals}+ meals logged.${kcal == null ? ' Add your profile in Settings to see your range.' : ''}',
            style: nunito(12, FontWeight.w700, colors.muted),
          ),
        ],
        if (overview.scale == OverviewScale.all) ...[
          const SizedBox(height: 4),
          Text('Each square is a week’s average.', style: nunito(12, FontWeight.w700, colors.muted)),
        ],
        if (withValue == 0) ...[
          const SizedBox(height: 6),
          Text('No ${metric.label.toLowerCase()} logged this $unit.', style: nunito(13, FontWeight.w700, colors.muted)),
        ],
      ],
    );
  }
}

class _MoodByGroup extends StatelessWidget {
  const _MoodByGroup({required this.overview, required this.colors});

  final PeriodOverview overview;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    final palette = YearMetric.mood.colors;
    final groups = overview.groups;
    // Week labels ("6–12") need room; keep at most a dozen or so readable.
    final labelSize = groups.length > 8 ? 10.0 : 11.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, g) in groups.indexed)
                Expanded(
                  child: Semantics(
                    label: '${g.name}: '
                        '${[for (var l = 0; l < 5; l++) if (overview.moodByGroup[i][l] > 0) '${YearMetric.mood.levels[l]} ${overview.moodByGroup[i][l]}'].join(', ')}',
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
                                      if (overview.moodByGroup[i][l] > 0)
                                        Expanded(flex: overview.moodByGroup[i][l], child: ColoredBox(color: Color(palette[l]), child: const SizedBox.expand())),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(g.short, maxLines: 1, style: nunito(labelSize, FontWeight.w800, colors.muted)),
                          ),
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

class _SleepByGroup extends StatelessWidget {
  const _SleepByGroup({required this.overview, required this.colors});

  final PeriodOverview overview;
  final GardenColors colors;

  static String clock(double hoursAfter6pm) {
    final minutes = ((hoursAfter6pm + 18) * 60 / 5).round() * 5 % (24 * 60);
    return '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final shortest = [for (final g in overview.sleepByGroup) ?g.hours].fold<double?>(null, (a, b) => a == null || b < a ? b : a);
    const night = Color(0xFF5B4FC9);
    const spread = Color(0xFFC9C3F5);
    const labelWidth = 44.0;
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: labelWidth),
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
        for (final g in overview.sleepByGroup)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Semantics(
              label: '${g.group.name}: ${overview.scale == OverviewScale.week ? 'asleep' : 'usually asleep'} ${clock(g.bed)} to ${clock(g.wake)}'
                  '${g.hours == null ? '' : ', ${g.hours!.toStringAsFixed(1)} hours${overview.scale == OverviewScale.week ? '' : ' on average'}'}',
              excludeSemantics: true,
              child: Row(
                children: [
                  SizedBox(width: labelWidth, child: Text(g.group.label, maxLines: 1, style: nunito(12, FontWeight.w900, colors.ink))),
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
                              if (g.bedHigh > g.bedLow) bar(g.bedLow, g.bedHigh, spread, 10),
                              if (g.wakeHigh > g.wakeLow) bar(g.wakeLow, g.wakeHigh, spread, 10),
                              bar(g.bed, g.wake, night, 12),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      g.hours == null ? '' : '${g.hours!.toStringAsFixed(1)}h',
                      textAlign: TextAlign.right,
                      style: nunito(12, g.hours == shortest ? FontWeight.w900 : FontWeight.w700, colors.ink),
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

  final PeriodOverview overview;
  final GardenColors colors;

  static const _palette = [Color(0xFF2F7D4C), Color(0xFFD9467A), Color(0xFFB7791F), Color(0xFF6B46C1), Color(0xFF2B6CB0)];

  @override
  Widget build(BuildContext context) {
    final start = overview.start;
    final length = math.max(1, daysBetween(start, overview.end));
    return Column(
      children: [
        for (final (i, tag) in overview.rareTags.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Semantics(
              label: '${tag.name} on ${tag.days.length} ${tag.days.length == 1 ? 'day' : 'days'}',
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
                              left: (box.maxWidth - 8) * daysBetween(start, d) / length,
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

class _Table extends StatelessWidget {
  const _Table({required this.overview, required this.sleepRange, required this.kcalRange, required this.profileSet, required this.colors});

  final PeriodOverview overview;
  final ValueRange sleepRange;
  final ValueRange? kcalRange;
  final bool profileSet;
  final GardenColors colors;

  /// -1 under the range, 1 over it, 0 in it or unknown.
  static int _side(double? v, ValueRange? range) {
    if (v == null || range == null || range.contains(v)) return 0;
    return v < range.low ? -1 : 1;
  }

  /// An arrow beside a value outside the range: a mark, not a colour alone.
  /// Drawn as an icon, as Nunito has no arrows.
  static InlineSpan _arrow(int side, Color color, double size) => WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(side < 0 ? Icons.arrow_downward : Icons.arrow_upward, size: size, color: color),
      );

  @override
  Widget build(BuildContext context) {
    final rows = overview.rows;
    double? best(double? Function(GroupRow) f) => [for (final r in rows) ?f(r)].fold<double?>(null, (a, b) => a == null || b > a ? b : a);
    final bestSleep = rows.length > 1 ? best((r) => r.sleep) : null;
    final bestSteps = rows.length > 1 ? best((r) => r.steps) : null;
    // Spending is SGD, shown as dollars like everywhere else in the app.
    final whole = NumberFormat('#,##0');
    String money(double v) => '\$${whole.format(v.round())}';
    const outside = Color(0xFFB86E12);
    Widget cell(String text, {bool bold = false, bool header = false, int side = 0}) => Expanded(
          child: Text.rich(
            TextSpan(text: text, children: [if (side != 0) _arrow(side, outside, 13)]),
            style: nunito(header ? 11 : 13, header || bold ? FontWeight.w900 : FontWeight.w700, header ? colors.muted : side != 0 ? outside : colors.ink),
          ),
        );
    String k(double? v) => v == null ? '–' : '${(v / 1000).toStringAsFixed(1)}k';
    const labelWidth = 44.0;
    final perDay = overview.scale == OverviewScale.week ? 'Kcal' : 'Kcal/day';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [const SizedBox(width: labelWidth), cell('Sleep', header: true), cell('Steps', header: true), cell(perDay, header: true), cell('Food', header: true), cell('Events', header: true)]),
        const Divider(height: 10),
        for (final r in rows)
          Semantics(
            label: r.group.name,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 30),
              child: Row(
                children: [
                  SizedBox(width: labelWidth, child: Text(r.group.label, maxLines: 1, style: nunito(13, FontWeight.w900, colors.ink))),
                  cell(
                    r.sleep == null ? '–' : '${r.sleep!.toStringAsFixed(1)}h',
                    bold: r.sleep != null && r.sleep == bestSleep,
                    side: _side(r.sleep, sleepRange),
                  ),
                  cell(k(r.steps), bold: r.steps != null && r.steps == bestSteps),
                  cell(k(r.kcal), side: _side(r.kcal, kcalRange)),
                  cell(r.food == 0 ? '–' : money(r.food)),
                  cell(r.events == 0 ? '–' : money(r.events)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(children: [
            if (rows.length > 1) TextSpan(text: 'Bold: the best ${overview.scale.groupNoun}. '),
            TextSpan(
              text: 'Your range: ${_hours(sleepRange)} sleep'
                  '${kcalRange == null ? '' : ', ${NumberFormat('#,##0').format(kcalRange!.low)}–${NumberFormat('#,##0').format(kcalRange!.high)} kcal'}'
                  '${profileSet ? '' : ' (adults)'}. ',
            ),
            _arrow(-1, outside, 12),
            const TextSpan(text: ' under, '),
            _arrow(1, outside, 12),
            const TextSpan(text: ' over. '),
            TextSpan(text: 'Calories are estimates, from days with ${PeriodOverview.completeDayMeals}+ meals logged.'),
            if (kcalRange == null) const TextSpan(text: ' Add your profile in Settings to see your calorie range.'),
          ]),
          style: nunito(12, FontWeight.w700, colors.muted),
        ),
      ],
    );
  }

  static String _hours(ValueRange r) => '${r.low.round()}–${r.high.round()}h';
}
