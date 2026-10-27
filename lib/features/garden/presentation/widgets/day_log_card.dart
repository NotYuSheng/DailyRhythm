import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/models/activity_entry.dart';
import '../../../../shared/providers/common_providers.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../../../exercise/data/models/exercise_entry.dart';
import '../../../exercise/data/providers/exercise_providers.dart';
import '../../../exercise/domain/effort.dart';
import '../../../exercise/presentation/screens/add_exercise_screen.dart';
import '../../../meals/data/models/meal_entry.dart';
import '../../../meals/data/providers/meal_providers.dart';
import '../../../meals/presentation/screens/add_meal_screen.dart';
import '../../../sleep/data/providers/sleep_providers.dart';
import '../../../sleep/presentation/screens/add_sleep_screen.dart';
import '../../../../shared/models/spending_entry.dart';
import '../../../spending/data/spending_providers.dart';
import '../../../spending/presentation/add_spending_screen.dart';
import '../../../tags/data/models/tag.dart';
import '../../../tags/data/providers/tag_providers.dart';
import '../../../tags/presentation/screens/tags_screen.dart';
import '../../data/garden_providers.dart';
import '../garden_style.dart';

/// Refreshes entries and plants after an edit. Every day, not just [day]:
/// a bedtime changes the next day's sleep, and an edit can move an entry
/// to another date. Only days on screen are fetched again.
void invalidateDayLog(WidgetRef ref, DateTime day) {
  ref.invalidate(sleepEntriesProvider);
  ref.invalidate(mealEntriesProvider);
  ref.invalidate(foodCaloriesProvider);
  ref.invalidate(spendingProvider);
  ref.invalidate(exerciseEntriesProvider);
  ref.invalidate(moodEntryProvider);
  ref.invalidate(activityEntriesProvider);
  invalidateGardenDay(ref, day);
}

/// Totals per currency ("\$12.40 + USD 20.00"): a trip abroad isn't added
/// up as dollars. Zero amounts are left out.
String moneyTotals(Iterable<(double, String)> amounts) {
  final totals = <String, double>{};
  for (final (amount, currency) in amounts) {
    if (amount > 0) totals[currency] = (totals[currency] ?? 0) + amount;
  }
  return [for (final e in totals.entries) formatMoney(e.value, e.key)].join(' + ');
}

/// "$3.50" for Singapore dollars, the app's home currency; "USD 22.00"
/// for anything else.
String formatMoney(double amount, String currency) =>
    currency == 'SGD' ? '\$${amount.toStringAsFixed(2)}' : '$currency ${amount.toStringAsFixed(2)}';

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
    final effort = ref.watch(gardenDayProvider(day)).value?.effort;
    final activities = ref.watch(activityEntriesProvider(day)).value ?? const <ActivityEntry>[];
    final spending = ref.watch(spendingProvider(day)).value ?? const <SpendingEntry>[];
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
    final spentText = moneyTotals([for (final m in meals) if (m.price != null) (m.price!, m.currency)]);
    // Calories as logged or from each food; an estimate, so "≈".
    final foodKcal = ref.watch(foodCaloriesProvider).value ?? const <int, double>{};
    final kcal = [for (final m in meals) ?m.caloriesWith(foodKcal)];
    final kcalText = kcal.isEmpty ? '' : ' · ≈${NumberFormat.decimalPattern().format(kcal.reduce((a, b) => a + b).round())} kcal';
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
                : '${meals.length} ${meals.length == 1 ? 'meal' : 'meals'}${spentText.isEmpty ? '' : ' · $spentText'}$kcalText',
            colors: colors,
            action: 'Add',
            onTap: () => open(AddMealScreen(date: day)),
          ),
          for (final m in meals)
            _Item(
              text: m.quantity > 1 ? '${m.quantity}× ${m.name}' : m.name,
              trailing: m.price == null ? null : formatMoney(m.price!, m.currency),
              colors: colors,
              onTap: () => open(AddMealScreen(entry: m)),
            ),
          _Row(
            icon: Icons.fitness_center_outlined,
            title: 'Exercise',
            summary: exercises.isEmpty
                ? 'Add exercise'
                : '${exercises.length} logged${effort == null ? '' : ' · ${Effort.labelFor(effort)} effort'}',
            colors: colors,
            action: 'Add',
            onTap: () => open(AddExerciseScreen(date: day)),
          ),
          for (final x in exercises)
            _Item(
              text: x.exerciseName ?? (x.type == ExerciseType.run ? 'Run' : 'Weights'),
              trailing: x.amount,
              colors: colors,
              onTap: () => open(AddExerciseScreen(entry: x)),
            ),
          _Row(
            icon: Icons.celebration_outlined,
            title: 'Events & gifts',
            summary: spending.isEmpty
                ? 'Not food: a celebration, a gift'
                : moneyTotals([for (final e in spending) (e.amount, e.currency)]),
            colors: colors,
            action: 'Add',
            onTap: () => open(AddSpendingScreen(date: day)),
          ),
          for (final e in spending)
            _Item(
              text: e.label,
              trailing: formatMoney(e.amount, e.currency),
              colors: colors,
              onTap: () => open(AddSpendingScreen(entry: e)),
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

  /// Toggles still saving, so a quick double tap can't add a tag twice.
  static final _saving = <(DateTime, int)>{};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);
    final tags = ref.watch(allTagsProvider).value ?? const <Tag>[];
    final entries = ref.watch(activityEntriesProvider(day)).value ?? const <ActivityEntry>[];
    final byTag = {for (final e in entries) e.tagId: e};

    Future<void> toggle(Tag tag) async {
      final key = (day, tag.id!);
      if (!_saving.add(key)) return;
      try {
        final db = ref.read(databaseProvider);
        // Read again: what was on screen may be out of date.
        final existing = (await db.getActivityEntriesByDate(day)).where((e) => e.tagId == tag.id).toList();
        if (existing.isNotEmpty) {
          for (final e in existing) {
            await db.deleteActivityEntry(e.id!);
          }
        } else {
          await db.createActivityEntry(ActivityEntry(date: day, timestamp: DateTime.now(), tagId: tag.id!));
        }
        ref.invalidate(activityEntriesProvider(day));
      } finally {
        _saving.remove(key);
      }
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
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: colors.accent),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const TagsScreen()));
                  ref.invalidate(allTagsProvider);
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text('Edit tags', style: nunito(14, FontWeight.w800, colors.accent)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
