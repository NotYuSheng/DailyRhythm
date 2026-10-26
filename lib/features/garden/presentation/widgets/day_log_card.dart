import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/models/activity_entry.dart';
import '../../../../shared/providers/common_providers.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../../../exercise/data/models/exercise_entry.dart';
import '../../../exercise/data/providers/exercise_providers.dart';
import '../../../exercise/presentation/screens/add_exercise_screen.dart';
import '../../../meals/data/models/meal_entry.dart';
import '../../../meals/data/providers/meal_providers.dart';
import '../../../meals/presentation/screens/add_meal_screen.dart';
import '../../../sleep/data/providers/sleep_providers.dart';
import '../../../sleep/presentation/screens/add_sleep_screen.dart';
import '../../../tags/data/models/tag.dart';
import '../../../tags/data/providers/tag_providers.dart';
import '../../data/garden_providers.dart';
import '../garden_style.dart';

/// Refreshes the day's entries and its plant after an edit.
void invalidateDayLog(WidgetRef ref, DateTime day) {
  ref.invalidate(sleepEntriesProvider(day));
  ref.invalidate(mealEntriesProvider(day));
  ref.invalidate(exerciseEntriesProvider(day));
  ref.invalidate(moodEntryProvider(day));
  ref.invalidate(activityEntriesProvider(day));
  invalidateGardenDay(ref, day);
}

/// The day's stats: sleep, meals, exercise and activities, each opening
/// its editor.
class DayLogCard extends ConsumerWidget {
  const DayLogCard({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);
    final sleep = ref.watch(sleepEntriesProvider(day)).value ?? const [];
    final meals = ref.watch(mealEntriesProvider(day)).value ?? const <MealEntry>[];
    final exercises = ref.watch(exerciseEntriesProvider(day)).value ?? const <ExerciseEntry>[];
    final activities = ref.watch(activityEntriesProvider(day)).value ?? const <ActivityEntry>[];
    final tags = {for (final t in ref.watch(allTagsProvider).value ?? const <Tag>[]) t.id: t};

    Future<void> open(Widget screen) async {
      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
      invalidateDayLog(ref, day);
    }

    final time = DateFormat('HH:mm');
    final night = sleep.isEmpty ? null : sleep.first;
    final sleepSummary = night == null
        ? 'Not logged'
        : [
            if (night.wakeUpTime != null) 'Woke ${time.format(night.wakeUpTime!)}',
            if (night.sleepTime != null) 'bed ${time.format(night.sleepTime!)}',
          ].join(' · ');
    final spent = meals.fold<double>(0, (sum, m) => sum + (m.price ?? 0));
    final activityNames = [for (final a in activities) tags[a.tagId]?.name].whereType<String>().toList()..sort();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your day', style: nunito(16, FontWeight.w900, colors.ink)),
          const SizedBox(height: 8),
          _Row(
            icon: Icons.bedtime_outlined,
            title: 'Sleep',
            summary: sleepSummary,
            colors: colors,
            onTap: () => open(AddSleepScreen(entry: night, date: day)),
          ),
          _Row(
            icon: Icons.restaurant_outlined,
            title: 'Meals',
            summary: meals.isEmpty
                ? 'Add a meal'
                : '${meals.length} ${meals.length == 1 ? 'meal' : 'meals'}${spent > 0 ? ' · \$${spent.toStringAsFixed(2)}' : ''}',
            colors: colors,
            action: 'Add',
            onTap: () => open(AddMealScreen(date: day)),
          ),
          for (final m in meals)
            _Item(
              text: m.quantity > 1 ? '${m.quantity}× ${m.name}' : m.name,
              trailing: m.price == null ? null : '\$${m.price!.toStringAsFixed(2)}',
              colors: colors,
              onTap: () => open(AddMealScreen(entry: m)),
            ),
          _Row(
            icon: Icons.fitness_center_outlined,
            title: 'Exercise',
            summary: exercises.isEmpty ? 'Add exercise' : '${exercises.length} logged',
            colors: colors,
            action: 'Add',
            onTap: () => open(AddExerciseScreen(date: day)),
          ),
          for (final x in exercises)
            _Item(
              text: x.type == ExerciseType.run ? 'Run' : x.exerciseName ?? 'Weights',
              trailing: x.amount,
              colors: colors,
              onTap: () => open(AddExerciseScreen(entry: x)),
            ),
          _Row(
            icon: Icons.local_activity_outlined,
            title: 'Activities',
            summary: activityNames.isEmpty ? 'Tag what you did' : activityNames.join(', '),
            colors: colors,
            onTap: () async {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => ActivitySheet(day: day),
              );
              invalidateDayLog(ref, day);
            },
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.summary,
    required this.colors,
    required this.onTap,
    this.action,
  });

  final IconData icon;
  final String title;
  final String summary;
  final GardenColors colors;
  final VoidCallback onTap;

  /// Shown instead of a chevron when the row adds rather than edits.
  final String? action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colors.leaf),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: nunito(15, FontWeight.w800, colors.ink)),
                  Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: nunito(13, FontWeight.w600, colors.muted)),
                ],
              ),
            ),
            if (action != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 18, color: colors.accent),
                  Text(action!, style: nunito(14, FontWeight.w800, colors.accent)),
                ],
              )
            else
              Icon(Icons.chevron_right, color: colors.muted),
          ],
        ),
      ),
    );
  }
}

/// One logged meal or exercise under its row; tap to edit.
class _Item extends StatelessWidget {
  const _Item({required this.text, required this.colors, required this.onTap, this.trailing});

  final String text;
  final String? trailing;
  final GardenColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Padding(
          padding: const EdgeInsets.only(left: 34),
          child: Row(
            children: [
              Expanded(child: Text(text, style: nunito(14, FontWeight.w600, colors.ink))),
              if (trailing != null) Text(trailing!, style: nunito(13, FontWeight.w700, colors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tag what the day included; each tap saves straight away.
class ActivitySheet extends ConsumerWidget {
  const ActivitySheet({super.key, required this.day});

  final DateTime day;

  static const _groups = [
    (TagKind.activity, 'Activities'),
    (TagKind.foodSource, 'Food from'),
    (TagKind.symptom, 'Symptoms'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);
    final tags = ref.watch(allTagsProvider).value ?? const <Tag>[];
    final entries = ref.watch(activityEntriesProvider(day)).value ?? const <ActivityEntry>[];
    final byTag = {for (final e in entries) e.tagId: e};

    Future<void> toggle(Tag tag) async {
      final db = ref.read(databaseProvider);
      final existing = byTag[tag.id];
      if (existing != null) {
        await db.deleteActivityEntry(existing.id!);
      } else {
        await db.createActivityEntry(ActivityEntry(date: day, timestamp: DateTime.now(), tagId: tag.id!));
      }
      ref.invalidate(activityEntriesProvider(day));
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('What today included', style: nunito(22, FontWeight.w900, colors.ink)),
            for (final (kind, title) in _groups)
              if (tags.any((t) => t.kind == kind)) ...[
                const SizedBox(height: 14),
                Text(title, style: nunito(15, FontWeight.w800, colors.leaf)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in tags.where((t) => t.kind == kind))
                      FilterChip(
                        label: Text(tag.name),
                        selected: byTag.containsKey(tag.id),
                        onSelected: (_) => toggle(tag),
                      ),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }
}
