import 'package:daily_rhythm/features/exercise/data/models/exercise_entry.dart';
import 'package:daily_rhythm/features/journal/data/models/journal_entry.dart';
import 'package:daily_rhythm/features/garden/presentation/widgets/day_log_card.dart';
import 'package:daily_rhythm/features/garden/presentation/screens/garden_month_screen.dart';
import 'package:daily_rhythm/features/garden/presentation/screens/garden_today_screen.dart';
import 'package:daily_rhythm/features/garden/presentation/widgets/moment_sheet.dart';
import 'package:daily_rhythm/features/garden/presentation/widgets/plant_view.dart';
import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/features/exercise/presentation/screens/add_exercise_screen.dart';
import 'package:daily_rhythm/features/meals/presentation/screens/add_meal_screen.dart';
import 'package:daily_rhythm/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_rhythm/shared/models/mood_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/services/database/repositories/checkin_repository.dart';
import 'package:daily_rhythm/shared/services/database/repositories/journal_repository.dart';
import 'package:daily_rhythm/shared/utils/date_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_database.dart';

/// Scrolls [finder] fully into view, then taps it. Lazily built rows can
/// exist just off screen, where a tap would miss.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  late DatabaseService db;
  final today = dayOf(DateTime.now());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await openTestDatabase();
  });
  tearDown(closeTestDatabase);

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1170, 2532); // 390×844 at 3×
    tester.view.devicePixelRatio = 3;
    // The plant sways unless reduced motion is on; tests can't settle on a loop.
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: screen)));
    await tester.pumpAndSettle();
  }

  testWidgets('today starts as an empty pot', (tester) async {
    await pump(tester, const GardenTodayScreen());
    expect(find.text('Today’s plant'), findsOneWidget);
    expect(find.text('An empty pot, ready for whatever today brings.'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Empty pot: nothing logged that day')), findsOneWidget);
  });

  testWidgets('"today was mostly" picks the plant, and picking it again goes back to automatic', (tester) async {
    await db.upsertMoodEntry(MoodEntry(date: today, timestamp: DateTime.now(), moodLevel: 3, emoji: ''));
    await pump(tester, const GardenTodayScreen());
    expect(find.textContaining('A sprout'), findsOneWidget);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(find.textContaining('A cactus'), findsOneWidget);
    expect(find.textContaining('(your pick)', findRichText: true), findsOneWidget);
    expect((await CheckinRepository(db).forDay(today))?.plantOverride, 'cactus');

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(find.textContaining('A sprout'), findsOneWidget);
    expect((await CheckinRepository(db).forDay(today))?.plantOverride, isNull);
  });

  testWidgets('check-in saves ratings relative to a usual day', (tester) async {
    await pump(tester, const GardenTodayScreen());
    await tester.scrollUntilVisible(find.bySemanticsLabel('Stress much lower'), 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.bySemanticsLabel('Stress much lower'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Energy a bit higher'));
    await tester.tap(find.bySemanticsLabel('Stress much lower'));
    await tester.pumpAndSettle();
    final checkin = await CheckinRepository(db).forDay(today);
    expect((checkin?.energy, checkin?.stress, checkin?.focus), (1, -2, null));
  });

  testWidgets('a good moment is saved and shown on the day', (tester) async {
    await pump(tester, const GardenTodayScreen());
    await tester.scrollUntilVisible(find.text('Log a moment'), 200, scrollable: find.byType(Scrollable).first);
    await tapVisible(tester, find.text('Log a moment'));

    await tester.enterText(find.byType(TextField), 'Coffee with an old friend');
    await tester.tap(find.descendant(of: find.byType(MomentSheet), matching: find.text('Great')));
    await tester.pump();
    await tester.ensureVisible(find.text('Save moment'));
    await tester.tap(find.text('Save moment'));
    await tester.pumpAndSettle();

    final saved = (await JournalRepository(db).forDay(today)).single;
    expect((saved.text, saved.mood, saved.time != null), ('Coffee with an old friend', 5, true));
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Coffee with an old friend'), 200, scrollable: scrollable);
  });

  testWidgets('a moment’s tags are grouped by category, symptoms last', (tester) async {
    await pump(tester, const GardenTodayScreen());
    await tester.scrollUntilVisible(find.text('Log a moment'), 200, scrollable: find.byType(Scrollable).first);
    await tapVisible(tester, find.text('Log a moment'));

    final sheet = find.byType(MomentSheet);
    final general = find.descendant(of: sheet, matching: find.text('General'));
    final health = find.descendant(of: sheet, matching: find.text('Health'));
    expect(general, findsOneWidget);
    expect(health, findsOneWidget);
    expect(tester.getTopLeft(health).dy, greaterThan(tester.getTopLeft(general).dy));
    expect(find.descendant(of: sheet, matching: find.widgetWithText(FilterChip, 'Work')), findsOneWidget);
  });

  testWidgets('mood and activities are set for the day, and the plant follows', (tester) async {
    await pump(tester, const GardenTodayScreen());
    final scrollable = find.byType(Scrollable).first;

    await tester.scrollUntilVisible(find.bySemanticsLabel('Mood good'), 200, scrollable: scrollable);
    await tapVisible(tester, find.bySemanticsLabel('Mood good'));
    expect((await db.getMoodEntryByDate(today))?.moodLevel, 4);
    await tester.scrollUntilVisible(find.text('Activities'), 200, scrollable: scrollable);
    await tapVisible(tester, find.text('Activities'));
    await tester.tap(find.widgetWithText(FilterChip, 'Work'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Work')).selected, isTrue);
    await tester.tap(find.widgetWithText(FilterChip, 'Work'));
    await tester.pumpAndSettle();
    expect(await db.getActivityEntriesByDate(today), isEmpty, reason: 'tapping again removes it');
    await tester.tap(find.widgetWithText(FilterChip, 'Social Event'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('What today included'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Social Event'), findsOneWidget);
    // The plant follows what the day held (the caption is back at the top).
    await tester.scrollUntilVisible(find.text('A tulip for time with people. From Social Event.'), -300, scrollable: scrollable);
  });

  testWidgets('the exercise row shows how hard the day was', (tester) async {
    await db.createExerciseEntry(ExerciseEntry(date: today, timestamp: today, type: ExerciseType.run, distance: 5));
    await pump(tester, const GardenTodayScreen());
    await tester.scrollUntilVisible(find.text('1 logged · Hard effort'), 200, scrollable: find.byType(Scrollable).first);
  });

  testWidgets('meals are listed and open the meal editor', (tester) async {
    await db.createMealEntry(MealEntry(date: today, time: DateTime.now(), name: 'Chicken rice', price: 4.5));
    await pump(tester, const GardenTodayScreen());
    final scrollable = find.byType(Scrollable).first;

    await tester.scrollUntilVisible(find.text('Chicken rice'), 200, scrollable: scrollable);
    expect(find.text('1 meal \u00b7 \$4.50 \u00b7 health 3/5'), findsOneWidget, reason: 'chicken rice: a typical plate');
    expect(find.text('Health 3/5 · a typical plate'), findsOneWidget, reason: 'each meal says its own');
    await tester.ensureVisible(find.text('Chicken rice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chicken rice'));
    await tester.pumpAndSettle();
    expect(find.byType(AddMealScreen), findsOneWidget);
  });

  testWidgets('app opens on Today; Garden, Metrics and Settings are tabs', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(const ProviderScope(child: DailyRhythmApp()));
    await tester.pumpAndSettle();
    expect(find.text('Today\u2019s plant'), findsOneWidget);
    expect(find.text('Journal'), findsNothing);

    await tester.tap(find.text('Garden').last);
    await tester.pumpAndSettle();
    expect(find.textContaining(' garden'), findsOneWidget);
    expect(find.byTooltip('Back to today'), findsNothing, reason: 'a tab has nothing to go back to');
  });

  testWidgets('the arrows step through days, and edits go to the day shown', (tester) async {
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    await db.createMealEntry(MealEntry(date: yesterday, time: yesterday, name: 'Chicken rice', price: 4));
    await db.createMealEntry(MealEntry(date: yesterday, time: yesterday, name: 'Apple'));
    await pump(tester, const GardenTodayScreen());
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull,
        reason: 'no stepping into the future');

    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();
    expect(find.text('This day\u2019s plant'), findsOneWidget);
    final scrollable = find.byType(Scrollable).first;

    await tester.scrollUntilVisible(find.bySemanticsLabel('Mood good'), 200, scrollable: scrollable);
    await tapVisible(tester, find.bySemanticsLabel('Mood good'));
    expect((await db.getMoodEntryByDate(yesterday))?.moodLevel, 4);
    expect(await db.getMoodEntryByDate(today), isNull);

    await tester.scrollUntilVisible(find.text('Apple'), 200, scrollable: scrollable);
    expect(find.text('Chicken rice'), findsOneWidget);
    expect(find.text('\$4.00'), findsOneWidget);

    await tester.ensureVisible(find.text('Meals'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meals'));
    await tester.pumpAndSettle();
    expect(tester.widget<AddMealScreen>(find.byType(AddMealScreen)).date, yesterday);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final exercise = find.descendant(of: find.byType(DayLogCard), matching: find.text('Exercise'));
    await tester.ensureVisible(exercise);
    await tester.pumpAndSettle();
    await tester.tap(exercise);
    await tester.pumpAndSettle();
    expect(tester.widget<AddExerciseScreen>(find.byType(AddExerciseScreen)).date, yesterday);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Today'), -300, scrollable: scrollable);
    await tapVisible(tester, find.text('Today'));
    expect(find.text('Today'), findsNothing, reason: 'no jump button on today itself');
    await tester.scrollUntilVisible(find.text('Today\u2019s plant'), -300, scrollable: scrollable);
  });

  testWidgets('the month garden counts plants and shows a picked day', (tester) async {
    await db.upsertMoodEntry(MoodEntry(date: DateTime(2025, 6, 3), timestamp: DateTime(2025, 6, 3), moodLevel: 4, emoji: ''));
    await db.upsertMoodEntry(MoodEntry(date: DateTime(2025, 6, 4), timestamp: DateTime(2025, 6, 4), moodLevel: 3, emoji: ''));
    await pump(tester, GardenMonthScreen(month: DateTime(2025, 6, 4)));

    expect(find.text('2 plants'), findsOneWidget);
    expect(find.byType(PlantView), findsNWidgets(30));
    expect(find.text('A sprout: a bit of everything'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp(r'^5 June, nothing logged')));
    await tester.pumpAndSettle();
    expect(find.text('A quiet day'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('May 2025 garden'), findsOneWidget);
    expect(find.text('0 plants'), findsOneWidget);
  });

  testWidgets('the month in review and the year of gardens open from the Garden tab', (tester) async {
    await db.upsertMoodEntry(MoodEntry(date: DateTime(2025, 6, 3), timestamp: DateTime(2025, 6, 3), moodLevel: 4, emoji: ''));
    await JournalRepository(db).save(JournalEntry(date: DateTime(2025, 6, 3), text: 'Picnic at the reservoir', mood: 5));
    await pump(tester, GardenMonthScreen(month: DateTime(2025, 6, 4)));

    await tapVisible(tester, find.text('June in review'));
    expect(find.text('Month in review'), findsOneWidget);
    expect(find.text('1 plant'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('“Picnic at the reservoir”'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Tue 3 Jun · Great'), findsOneWidget);

    await tapVisible(tester, find.text('2025’s gardens'));
    expect(find.text('A year of gardens'), findsOneWidget);
    expect(find.text('2025'), findsOneWidget);
    expect(find.text('1 plant'), findsOneWidget);
    expect(find.text('Every day of the year'), findsNothing, reason: 'the year’s numbers are in Metrics');
    await tester.scrollUntilVisible(find.bySemanticsLabel('June: 1 plant'), 300, scrollable: find.byType(Scrollable).first);
    await tapVisible(tester, find.bySemanticsLabel('June: 1 plant'));
    expect(find.text('Month in review'), findsOneWidget, reason: 'a month tile opens its review');
  });
}
