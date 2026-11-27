import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../exercise/data/providers/weekly_guide_provider.dart';
import '../../../exercise/domain/weekly_guide.dart';
import '../../../garden/presentation/garden_style.dart';

/// The last 7 days of exercise against the weekly guide, and advice.
class WeeklyGuideSection extends ConsumerWidget {
  const WeeklyGuideSection({super.key, this.today});

  /// The week's last day; today when null.
  final DateTime? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);
    final now = today ?? DateTime.now();
    final guide = ref.watch(weeklyGuideProvider(DateTime(now.year, now.month, now.day))).value;
    if (guide == null) return const SizedBox.shrink();
    final t = guide.targets;
    return GardenSection(
      title: 'Your last 7 days',
      subtitle: 'Against ${t.minutes} active minutes and ${t.strengthDays} strength '
          '${t.strengthDays == 1 ? 'day' : 'days'} a week (WHO guide; change it in Settings). Vigorous minutes count double.',
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Bar(label: 'Active minutes', value: guide.minutes, target: t.minutes.toDouble(), text: '${guide.minutes.round()} of ${t.minutes}', colors: colors),
          const SizedBox(height: 10),
          _Bar(
            label: 'Strength days',
            value: guide.strengthDays.toDouble(),
            target: t.strengthDays.toDouble(),
            text: '${guide.strengthDays} of ${t.strengthDays}',
            colors: colors,
          ),
          const SizedBox(height: 12),
          for (final line in guide.advice)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 8),
                    child: Icon(Icons.tips_and_updates_outlined, size: 16, color: DayTone.move.ink(context)),
                  ),
                  Expanded(child: Text(line, style: nunito(13, FontWeight.w700, colors.ink))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.target, required this.text, required this.colors});

  final String label;
  final double value;
  final double target;
  final String text;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    final met = value >= target;
    return Semantics(
      label: '$label: $text${met ? ', met' : ''}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: nunito(13, FontWeight.w800, colors.ink))),
              if (met) Icon(Icons.check_circle, size: 16, color: DayTone.move.ink(context)),
              const SizedBox(width: 4),
              Text(text, style: nunito(13, FontWeight.w800, colors.muted)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: target <= 0 ? 1 : (value / target).clamp(0, 1).toDouble(),
              backgroundColor: colors.ground,
              color: DayTone.move.ink(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks the weekly targets, for Settings.
class WeeklyTargetsPicker extends ConsumerWidget {
  const WeeklyTargetsPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(weeklyTargetsProvider);
    final notifier = ref.read(weeklyTargetsProvider.notifier);
    Widget row(String label, List<int> choices, int chosen, String Function(int) text, void Function(int) pick) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in choices) ChoiceChip(label: Text(text(c)), selected: chosen == c, onSelected: (_) => pick(c)),
                ],
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row('Active minutes a week', WeeklyTargets.minuteChoices, t.minutes, (m) => '$m', (m) => notifier.set(minutes: m)),
        row('Strength days a week', WeeklyTargets.strengthChoices, t.strengthDays, (d) => '$d', (d) => notifier.set(strengthDays: d)),
      ],
    );
  }
}
