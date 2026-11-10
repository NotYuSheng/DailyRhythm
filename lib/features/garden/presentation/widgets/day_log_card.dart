import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/models/activity_entry.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/providers/common_providers.dart';
import '../../../../shared/utils/date_utils.dart';
import '../../../exercise/data/models/exercise_entry.dart';
import '../../../exercise/data/providers/exercise_providers.dart';
import '../../../exercise/domain/effort.dart';
import '../../../meals/domain/diet_score.dart';
import '../../../profile/data/profile_providers.dart';
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
import '../../data/garden_providers.dart';
import '../../../tags/presentation/tag_icons.dart';
import '../garden_style.dart';
import '../../../tags/presentation/screens/tag_calendar_screen.dart';
import '../screens/activities_screen.dart';

/// Refreshes entries and plants after an edit. Every day, not just [day]:
/// a bedtime changes the next day's sleep, and an edit can move an entry
/// to another date. Only days on screen are fetched again.
void invalidateDayLog(WidgetRef ref, DateTime day) {
  ref.invalidate(sleepEntriesProvider);
  ref.invalidate(mealEntriesProvider);
  ref.invalidate(foodCaloriesProvider);
  ref.invalidate(foodHealthTagsProvider);
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
String formatMoney(double amount, String currency) => currency == 'SGD' ? '\$${amount.toStringAsFixed(2)}' : '$currency ${amount.toStringAsFixed(2)}';

/// The day's stats: sleep, meals, exercise and activities, each opening
/// its editor.
class DayLogCard extends ConsumerWidget {
  const DayLogCard({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);
    final sleep = ref.watch(sleepEntriesProvider(day)).value ?? const [];
    // Last night began with the day before's bedtime.
    final dayBefore = ref.watch(sleepEntriesProvider(DateTime(day.year, day.month, day.day - 1))).value ?? const [];
    final meals = ref.watch(mealEntriesProvider(day)).value ?? const <MealEntry>[];
    final exercises = ref.watch(exerciseEntriesProvider(day)).value ?? const <ExerciseEntry>[];
    final garden = ref.watch(gardenDayProvider(day)).value;
    final effort = garden?.effort;
    final health = DietScore.levelFor(garden?.diet);
    final activities = ref.watch(activityEntriesProvider(day)).value ?? const <ActivityEntry>[];
    final spending = ref.watch(spendingProvider(day)).value ?? const <SpendingEntry>[];
    final tags = {for (final t in ref.watch(allTagsProvider).value ?? const <Tag>[]) t.id: t};

    Future<void> open(Widget screen) async {
      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
      invalidateDayLog(ref, day);
    }

    final time = DateFormat('HH:mm');
    final night = sleep.isEmpty ? null : sleep.first;
    final wentToBed = dayBefore.isEmpty ? null : dayBefore.first.sleepTime;
    final woke = night?.wakeUpTime;
    final bedTonight = night?.sleepTime;
    final naps = night?.napHours ?? 0;
    final isToday = dayOf(DateTime.now()) == dayOf(day);
    final spentText = moneyTotals([
      for (final m in meals)
        if (m.price != null) (m.price!, m.currency),
    ]);
    // Calories as logged or from each food; an estimate, so "≈".
    final foodKcal = ref.watch(foodCaloriesProvider).value ?? const <int, double>{};
    final foodTags = ref.watch(foodHealthTagsProvider).value ?? const <int, List<String>>{};
    final kcal = [for (final m in meals) ?m.caloriesWith(foodKcal)];
    final weight = ref.watch(profileProvider).value?.weightKg ?? Effort.defaultWeightKg;
    double burned(ExerciseEntry x) => Effort.kcalBurned(
      run: x.type == ExerciseType.run,
      weightKg: weight,
      name: x.exerciseName,
      reps: x.reps,
      sets: x.sets,
      km: x.distance,
      notes: x.notes,
      duration: x.duration,
    );
    final burnedTotal = exercises.fold(0.0, (sum, x) => sum + burned(x));
    String approx(double kcal) => '≈${NumberFormat.decimalPattern().format(kcal.round())} kcal';
    final dayTags = [for (final a in activities) ?tags[a.tagId]]..sort((a, b) => a.name.compareTo(b.name));
    final activityNames = [for (final t in dayTags) t.name];

    final kcalTotal = kcal.isEmpty ? null : kcal.reduce((a, b) => a + b);
    final number = NumberFormat.decimalPattern();
    final hours = night?.totalHours;
    final eventsTotal = spending.isEmpty ? '' : moneyTotals([for (final e in spending) (e.amount, e.currency)]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text('Your day', style: nunito(20, FontWeight.w900, colors.ink))),
        const SizedBox(height: 10),
        _Tile(
          tone: DayTone.sleep,
          icon: Icons.bedtime_outlined,
          label: 'Sleep',
          // Last night, as when you went to bed and woke; its length below.
          headline: wentToBed != null && woke != null
              ? '${time.format(wentToBed)} → ${time.format(woke)}'
              : woke != null
              ? 'Woke ${time.format(woke)}'
              : hours != null
              ? formatHours(hours)
              : 'Not logged',
          summary: [
            if (hours != null && woke != null)
              '${formatHours(hours)} asleep last night'
            else if (woke != null)
              'Add last night’s bedtime to see how long you slept'
            else
              'Tap to log when you went to bed and woke',
            if (naps > 0) 'nap ${formatHours(naps)}',
          ].join(' · '),
          colors: colors,
          onTap: () => open(AddSleepScreen(entry: night, date: day)),
          items: [
            if (bedTonight != null)
              _Item(
                text: isToday ? 'Bedtime tonight' : 'Bedtime that night',
                trailing: time.format(bedTonight),
                colors: colors,
                onTap: () => open(AddSleepScreen(entry: night, date: day)),
              ),
          ],
        ),
        _Tile(
          tone: DayTone.food,
          icon: Icons.restaurant_outlined,
          label: 'Meals',
          headline: meals.isEmpty
              ? 'Add a meal'
              : [if (kcalTotal != null) '≈${number.format(kcalTotal.round())} kcal', if (spentText.isNotEmpty) spentText].join(' · ').ifEmpty ??
                    '${meals.length} ${meals.length == 1 ? 'meal' : 'meals'}',
          summary: meals.isEmpty
              ? 'Breakfast, lunch, dinner, snacks'
              : '${meals.length} ${meals.length == 1 ? 'meal' : 'meals'}${health == null ? '' : ' · health $health/5'}',
          colors: colors,
          adds: true,
          onTap: () => open(AddMealScreen(date: day)),
          onReorder: (from, to) async {
            final ids = [for (final m in meals) m.id!];
            ids.insert(to, ids.removeAt(from));
            await ref.read(databaseProvider).reorderMeals(ids);
            ref.invalidate(mealEntriesProvider(day));
          },
          items: [
            for (final m in meals)
              _Item(
                key: ValueKey(('meal', m.id)),
                text: m.quantity > 1 ? '${m.quantity}× ${m.name}' : m.name,
                // Its calories, then how healthy it is and why.
                detail: [
                  if (m.caloriesWith(foodKcal) case final kcal?) approx(kcal),
                  ?DietScore.describe(m.name, tags: m.healthTags ?? foodTags[m.foodItemId]),
                ].join(' · ').ifEmpty,
                trailing: m.price == null ? null : formatMoney(m.price!, m.currency),
                colors: colors,
                onTap: () => open(AddMealScreen(entry: m)),
              ),
          ],
        ),
        _Tile(
          tone: DayTone.move,
          icon: Icons.fitness_center_outlined,
          label: 'Exercise',
          headline: exercises.isEmpty
              ? 'Add exercise'
              : effort == null
              ? '${exercises.length} logged'
              : '${Effort.labelFor(effort)} effort',
          summary: exercises.isEmpty ? 'Workouts, runs, walks' : '${exercises.length} logged · ${approx(burnedTotal)} burned',
          colors: colors,
          adds: true,
          onTap: () => open(AddExerciseScreen(date: day)),
          items: [
            for (final x in exercises)
              _Item(
                text: x.exerciseName ?? (x.type == ExerciseType.run ? 'Run' : 'Weights'),
                detail: '${approx(burned(x))} burned',
                trailing: x.amount,
                colors: colors,
                onTap: () => open(AddExerciseScreen(entry: x)),
              ),
          ],
        ),
        _Tile(
          tone: DayTone.gift,
          icon: Icons.celebration_outlined,
          label: 'Events & gifts',
          headline: spending.isEmpty ? 'None' : eventsTotal,
          summary: 'Celebrations, outings and gifts',
          colors: colors,
          adds: true,
          onTap: () => open(AddSpendingScreen(date: day)),
          items: [
            for (final e in spending)
              _Item(
                text: e.label,
                trailing: formatMoney(e.amount, e.currency),
                colors: colors,
                onTap: () => open(AddSpendingScreen(entry: e)),
              ),
          ],
        ),
        _Tile(
          tone: DayTone.tag,
          icon: Icons.local_activity_outlined,
          label: 'Activities',
          headline: activityNames.isEmpty ? 'Tag what you did' : '${activityNames.length} ${activityNames.length == 1 ? 'tag' : 'tags'}',
          summary: activityNames.isEmpty ? 'Activities, where food came from, symptoms' : 'Tap to change',
          colors: colors,
          onTap: () => open(ActivitiesScreen(day: day)),
          items: [
            if (dayTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final t in dayTags) _TagChip(tag: t, tone: DayTone.tag, colors: colors)],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// One kind of entry as its own tile: a coloured icon, a small label, the
/// day's headline number and a line under it, then the entries.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.tone,
    required this.icon,
    required this.label,
    required this.headline,
    required this.summary,
    required this.colors,
    required this.onTap,
    this.adds = false,
    this.items = const [],
    this.onReorder,
  });

  final DayTone tone;
  final IconData icon;
  final String label;
  final String headline;
  final String summary;
  final GardenColors colors;
  final VoidCallback onTap;

  /// Tapping adds an entry (a + button) rather than opening one (a chevron).
  final bool adds;
  final List<Widget> items;

  /// When set, the items can be dragged into another order (press and
  /// hold, or use the handle); called with the old and new positions.
  final void Function(int from, int to)? onReorder;

  @override
  Widget build(BuildContext context) {
    final ink = tone.ink(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.card,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: tone.tint(context), borderRadius: BorderRadius.circular(13)),
                      child: Icon(icon, size: 22, color: ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: nunito(13, FontWeight.w800, ink)),
                          Text(headline, maxLines: 2, overflow: TextOverflow.ellipsis, style: nunito(19, FontWeight.w900, colors.ink)),
                          Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: nunito(13, FontWeight.w700, colors.muted)),
                        ],
                      ),
                    ),
                    if (adds)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.hill, width: 1.5),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(Icons.add, size: 20, color: colors.accent, semanticLabel: 'Add'),
                      )
                    else
                      Icon(Icons.chevron_right, color: colors.muted),
                  ],
                ),
              ),
            ),
            if (items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                child: onReorder == null || items.length < 2
                    ? Column(children: items)
                    : ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        proxyDecorator: (child, _, _) =>
                            Material(color: colors.card, elevation: 4, borderRadius: BorderRadius.circular(10), child: child),
                        onReorderItem: (from, to) => onReorder!(from, to),
                        children: [
                          for (final (i, item) in items.indexed)
                            ReorderableDelayedDragStartListener(
                              key: item.key ?? ValueKey(i),
                              index: i,
                              child: Row(
                                children: [
                                  Expanded(child: item),
                                  ReorderableDragStartListener(
                                    index: i,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Icon(Icons.drag_indicator, size: 20, color: colors.muted, semanticLabel: 'Drag to reorder'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One logged entry in its tile; tap to edit.
class _Item extends StatelessWidget {
  const _Item({super.key, required this.text, required this.colors, required this.onTap, this.trailing, this.detail});

  final String text;

  /// A second, quieter line: a meal's health score and why.
  final String? detail;
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.ground, width: 1.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text, style: nunito(14, FontWeight.w600, colors.ink)),
                      if (detail != null) Text(detail!, style: nunito(12, FontWeight.w700, colors.muted)),
                    ],
                  ),
                ),
              ),
              if (trailing != null) Text(trailing!, style: nunito(13, FontWeight.w700, colors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tag the day has, with its icon, in the tile's colour.
class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, required this.tone, required this.colors});

  final Tag tag;
  final DayTone tone;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    // Tapping a tag shows every day it was logged.
    return Material(
      color: tone.tint(context),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => openTagCalendar(context, tag),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tagIcon(tag), size: 16, color: tone.ink(context)),
              const SizedBox(width: 5),
              Text(tag.name, style: nunito(13, FontWeight.w800, colors.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

extension on String {
  /// Null for an empty line, so nothing is shown.
  String? get ifEmpty => isEmpty ? null : this;
}
