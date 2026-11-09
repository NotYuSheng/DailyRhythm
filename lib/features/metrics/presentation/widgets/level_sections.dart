import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../exercise/domain/effort.dart';
import '../../../garden/presentation/garden_style.dart';
import '../../../profile/data/profile_providers.dart';
import '../../../profile/domain/profile.dart';
import '../../data/models/metric_data.dart';
import '../../data/services/level_report.dart';
import 'period_overview_section.dart' show YearMetric;

/// How hard the period's exercise days were, by the effort level Today
/// gives each one.
class EffortSection extends ConsumerWidget {
  const EffortSection({super.key, required this.range});

  final DateRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LevelCard(
      title: 'Exercise effort',
      subtitle: 'How hard each exercise day was, from what you logged',
      empty: 'Log exercise to see how hard your days were.',
      report: ref.watch(effortReportProvider(range)),
      levels: Effort.levels,
      palette: YearMetric.effort.colors,
      stats: (r) => [
        ('${r.counted}', 'of ${r.days} ${r.days == 1 ? 'day' : 'days'}'),
        (Effort.levels[r.usual!], 'usually'),
        ('${r.byLevel[3] + r.byLevel[4]}', r.byLevel[3] + r.byLevel[4] == 1 ? 'hard day' : 'hard days'),
      ],
      change: (r) => switch ((r.perWeek, r.previousPerWeek)) {
        (final now?, final was?) when (now - was).abs() >= 0.3 =>
          '${now.toStringAsFixed(1)} exercise days a week, ${now > was ? 'up' : 'down'} from ${was.toStringAsFixed(1)} ${previousWord(range)}',
        (final now?, _?) => 'About ${now.toStringAsFixed(1)} exercise days a week, as ${previousWord(range)}',
        _ => null,
      },
      weekdayNoun: 'exercise',
    );
  }
}

/// How much was eaten on the period's days with calories, in the bands the
/// overview colours them (against your range when the profile gives one).
class CalorieSection extends ConsumerWidget {
  const CalorieSection({super.key, required this.range});

  final DateRange range;

  static final _number = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value ?? const Profile();
    final kcal = PersonalRanges.kcalFor(profile, DateTime.now());
    String k(double v) => _number.format(v.round());
    return LevelCard(
      title: 'Calories',
      subtitle: kcal == null ? 'Days with meals, by calories eaten' : 'Days with meals, against your range of ${k(kcal.low)}–${k(kcal.high)}',
      empty: 'Add calories to meals to see this.',
      report: ref.watch(calorieReportProvider((range, kcal?.low, kcal?.high))),
      levels: YearMetric.calories.levelsFor(kcal),
      palette: YearMetric.calories.colorsFor(kcal),
      stats: (r) => [
        ('≈${k(r.average!)}', 'a day'),
        ('${r.counted}', 'of ${r.days} ${r.days == 1 ? 'day' : 'days'}'),
        (kcal == null ? YearMetric.calories.levelsFor(null)[r.usual!] : '${r.byLevel[2]}', kcal == null ? 'usually' : r.byLevel[2] == 1 ? 'day in range' : 'days in range'),
      ],
      change: (r) => switch ((r.average, r.previousAverage)) {
        (final now?, final was?) when (now - was).abs() >= 50 =>
          '≈${k(now)} a day, ${now > was ? 'up' : 'down'} from ≈${k(was)} ${previousWord(range)}',
        (final now?, _?) => 'About ≈${k(now)} a day, as ${previousWord(range)}',
        _ => null,
      },
      note: 'Only days with calories on their meals count, and a day is only as full as what was logged.',
      weekdayNoun: 'logged',
    );
  }
}

/// A card for days sorted into five levels: three numbers, every day by
/// level, each weekday's days stacked by level, and the change against the
/// period before.
class LevelCard extends StatelessWidget {
  const LevelCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.empty,
    required this.report,
    required this.levels,
    required this.palette,
    required this.stats,
    required this.change,
    required this.weekdayNoun,
    this.note,
  });

  final String title;
  final String subtitle;

  /// What to say when no day has a level.
  final String empty;
  final AsyncValue<LevelReport> report;
  final List<String> levels;
  final List<int> palette;

  /// The three numbers at the top: (value, what it is).
  final List<(String, String)> Function(LevelReport) stats;
  final String? Function(LevelReport) change;

  /// Fills "Most exercise days on Saturdays".
  final String weekdayNoun;

  /// A quieter line at the bottom.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    return GardenSection(
      title: title,
      subtitle: subtitle,
      colors: colors,
      child: report.when(
        loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
        error: (_, _) => Text('$title isn’t available right now.', style: nunito(14, FontWeight.w600, colors.muted)),
        data: (r) => r.counted == 0 ? Text(empty, style: nunito(14, FontWeight.w600, colors.muted)) : _body(r, colors),
      ),
    );
  }

  Widget _body(LevelReport r, GardenColors colors) {
    final shades = [for (final c in palette) Color(c)];
    String dayName(int weekday) => DateFormat('EEEE').format(DateTime(2024, 1, weekday)); // 1 Jan 2024 was a Monday
    final busiest = r.busiestWeekday;
    final most = r.byWeekday.map((w) => w.fold(0, (a, b) => a + b)).reduce((a, b) => a > b ? a : b);
    final changeText = change(r);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [for (final (value, label) in stats(r)) _Stat(value: value, label: label, colors: colors)]),
        const SizedBox(height: 14),
        // Every counted day, lowest level to highest.
        Semantics(
          label: [for (var i = 0; i < 5; i++) if (r.byLevel[i] > 0) '${levels[i]} ${r.byLevel[i]}'].join(', '),
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 18,
                  child: Row(
                    children: [
                      for (var i = 0; i < 5; i++)
                        if (r.byLevel[i] > 0) Expanded(flex: r.byLevel[i], child: ColoredBox(color: shades[i], child: const SizedBox.expand())),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < 5; i++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: shades[i], borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 4),
                        Text('${levels[i]} ${r.byLevel[i]}', style: nunito(12, FontWeight.w700, colors.muted)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(busiest == null ? 'By weekday' : 'Most $weekdayNoun days on ${dayName(busiest)}s', style: nunito(14, FontWeight.w800, colors.ink)),
        const SizedBox(height: 8),
        // Each weekday's days, stacked lowest level at the bottom.
        Semantics(
          label: [
            for (var d = 0; d < 7; d++)
              if (r.byWeekday[d].any((n) => n > 0))
                '${dayName(d + 1)}: ${[for (var i = 0; i < 5; i++) if (r.byWeekday[d][i] > 0) '${levels[i]} ${r.byWeekday[d][i]}'].join(', ')}',
          ].join('. '),
          excludeSemantics: true,
          child: SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (r.byWeekday[d].fold(0, (a, b) => a + b) case final total when total > 0) ...[
                            Text('$total', style: nunito(11, FontWeight.w800, colors.muted)),
                            const SizedBox(height: 2),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                height: 6 + total / most * 54,
                                child: Column(
                                  children: [
                                    for (var i = 4; i >= 0; i--)
                                      if (r.byWeekday[d][i] > 0)
                                        Expanded(flex: r.byWeekday[d][i], child: ColoredBox(color: shades[i], child: const SizedBox.expand())),
                                  ],
                                ),
                              ),
                            ),
                          ] else
                            Container(height: 3, color: colors.ground),
                          const SizedBox(height: 4),
                          Text(DateFormat('EEEEE').format(DateTime(2024, 1, d + 1)), style: nunito(12, FontWeight.w800, colors.muted)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (changeText != null) ...[
          const SizedBox(height: 12),
          Text(changeText, style: nunito(13, FontWeight.w600, colors.muted)),
        ],
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(note!, style: nunito(12, FontWeight.w600, colors.muted)),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.colors});

  final String value;
  final String label;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, maxLines: 1, style: nunito(20, FontWeight.w900, colors.ink)),
            ),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: nunito(12, FontWeight.w700, colors.muted)),
          ],
        ),
      ),
    );
  }
}
