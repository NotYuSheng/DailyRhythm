import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../exercise/domain/effort.dart';
import '../../../garden/presentation/garden_style.dart';
import '../../data/models/metric_data.dart';
import '../../data/services/effort_report.dart';
import 'period_overview_section.dart' show YearMetric;

/// How hard the period's exercise was: the effort level of each exercise
/// day (as Today rates it), the usual level, which weekdays are hardest,
/// and how often you exercised against the period before.
class EffortSection extends ConsumerWidget {
  const EffortSection({super.key, required this.range});

  final DateRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);
    final report = ref.watch(effortReportProvider(range));
    return GardenSection(
      title: 'Exercise effort',
      subtitle: 'How hard each exercise day was, from what you logged',
      colors: colors,
      child: report.when(
        loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
        error: (_, _) => Text('Exercise effort isn’t available right now.', style: nunito(14, FontWeight.w600, colors.muted)),
        data: (r) => r.exerciseDays == 0
            ? Text('Log exercise to see how hard your days were.', style: nunito(14, FontWeight.w600, colors.muted))
            : _EffortBody(
                report: r,
                colors: colors,
                before: switch (previousPeriod(range)?.label) {
                  final l? when l == '${range.start.year - 1}' => 'last year',
                  final l? when l.contains('–') => 'last week',
                  _ => 'last month',
                },
              ),
      ),
    );
  }
}

class _EffortBody extends StatelessWidget {
  const _EffortBody({required this.report, required this.colors, required this.before});

  final EffortReport report;

  /// "last month", "last week" or "last year".
  final String before;
  final GardenColors colors;

  static final shades = [for (final c in YearMetric.effort.colors) Color(c)];

  @override
  Widget build(BuildContext context) {
    final r = report;
    String dayName(int weekday) => DateFormat('EEEE').format(DateTime(2024, 1, weekday)); // 1 Jan 2024 was a Monday
    final hardest = r.hardestWeekday;
    final change = switch ((r.perWeek, r.previousPerWeek)) {
      (final now?, final was?) when (now - was).abs() >= 0.3 =>
        '${now.toStringAsFixed(1)} exercise days a week, ${now > was ? 'up' : 'down'} from ${was.toStringAsFixed(1)} $before',
      (final now?, _?) => 'About ${now.toStringAsFixed(1)} exercise days a week, as $before',
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Stat(value: '${r.exerciseDays}', label: 'of ${r.days} ${r.days == 1 ? 'day' : 'days'}', colors: colors),
            _Stat(value: Effort.labelFor(r.usual!), label: 'usually', colors: colors),
            _Stat(value: '${r.hardDays}', label: r.hardDays == 1 ? 'hard day' : 'hard days', colors: colors),
          ],
        ),
        const SizedBox(height: 14),
        // Every exercise day, Light to Very hard.
        Semantics(
          label: [
            for (var i = 0; i < 5; i++)
              if (r.byLevel[i] > 0) '${Effort.levels[i]} ${r.byLevel[i]}',
          ].join(', '),
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
                        if (r.byLevel[i] > 0)
                          Expanded(
                            flex: r.byLevel[i],
                            child: ColoredBox(color: shades[i], child: const SizedBox.expand()),
                          ),
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
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: shades[i], borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(width: 4),
                        Text('${Effort.levels[i]} ${r.byLevel[i]}', style: nunito(12, FontWeight.w700, colors.muted)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        if (r.byWeekday.where((v) => v != null).length >= 2) ...[
          const SizedBox(height: 16),
          Text(hardest == null ? 'By weekday' : 'Hardest on ${dayName(hardest)}s', style: nunito(14, FontWeight.w800, colors.ink)),
          const SizedBox(height: 8),
          Semantics(
            label: [
              for (var i = 0; i < 7; i++)
                if (r.byWeekday[i] != null) '${dayName(i + 1)} ${Effort.labelFor(r.byWeekday[i]!.round())}',
            ].join(', '),
            excludeSemantics: true,
            child: SizedBox(
              height: 74,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (r.byWeekday[i] case final v?)
                              Container(
                                height: 8 + (v - 1) / 4 * 44,
                                decoration: BoxDecoration(color: shades[(v.round() - 1).clamp(0, 4)], borderRadius: BorderRadius.circular(6)),
                              )
                            else
                              Container(height: 3, color: colors.ground),
                            const SizedBox(height: 4),
                            Text(DateFormat('EEEEE').format(DateTime(2024, 1, i + 1)), style: nunito(12, FontWeight.w800, colors.muted)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (change != null) ...[const SizedBox(height: 12), Text(change, style: nunito(13, FontWeight.w600, colors.muted))],
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
