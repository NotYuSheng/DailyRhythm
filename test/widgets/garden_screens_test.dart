import 'package:daily_rhythm/features/garden/presentation/screens/garden_month_screen.dart';
import 'package:daily_rhythm/features/garden/presentation/screens/garden_today_screen.dart';
import 'package:daily_rhythm/features/garden/presentation/widgets/moment_sheet.dart';
import 'package:daily_rhythm/features/garden/presentation/widgets/plant_view.dart';
import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/features/meals/presentation/screens/add_meal_screen.dart';
import 'package:daily_rhythm/shared/models/mood_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/services/database/repositories/checkin_repository.dart';
import 'package:daily_rhythm/shared/services/database/repositories/journal_repository.dart';
import 'package:daily_rhythm/shared/utils/date_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_database.dart';

void main() {
  late DatabaseService db;
  final today = dayOf(DateTime.now());

  setUp(() async => db = await openTestDatabase());
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

  testWidgets('a good moment is saved and blooms the plant', (tester) async {
    await pump(tester, const GardenTodayScreen());
    await tester.scrollUntilVisible(find.text('Log a moment'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Log a moment'));
    await tester.pumpAndSettle();

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
    await tester.scrollUntilVisible(find.textContaining('is in bloom'), -300, scrollable: scrollable);
  });

  testWidgets('your day sets the mood and tags activities, and the plant follows', (tester) async {
    await pump(tester, const GardenTodayScreen());
    final scrollable = find.byType(Scrollable).first;

    await tester.scrollUntilVisible(find.text('Good'), 200, scrollable: scrollable);
    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();
    expect((await db.getMoodEntryByDate(today))?.moodLevel, 4);
    // A good day mood blooms (the caption is back at the top).
    await tester.scrollUntilVisible(find.textContaining('is in bloom'), -300, scrollable: scrollable);

    await tester.scrollUntilVisible(find.text('Activities'), 200, scrollable: scrollable);
    await tester.tap(find.text('Activities'));
    await tester.pumpAndSettle();
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
    await tester.scrollUntilVisible(find.textContaining('Your tulip is in bloom'), -300, scrollable: scrollable);
  });

  testWidgets('meals are listed and open the meal editor', (tester) async {
    await db.createMealEntry(MealEntry(date: today, time: DateTime.now(), name: 'Chicken rice', price: 4.5));
    await pump(tester, const GardenTodayScreen());
    final scrollable = find.byType(Scrollable).first;

    await tester.scrollUntilVisible(find.text('Chicken rice'), 200, scrollable: scrollable);
    expect(find.text('1 meal \u00b7 \$4.50'), findsOneWidget);
    await tester.ensureVisible(find.text('Chicken rice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chicken rice'));
    await tester.pumpAndSettle();
    expect(find.byType(AddMealScreen), findsOneWidget);
  });

  testWidgets('the month garden counts plants and flowers and shows a picked day', (tester) async {
    await db.upsertMoodEntry(MoodEntry(date: DateTime(2025, 6, 3), timestamp: DateTime(2025, 6, 3), moodLevel: 4, emoji: ''));
    await db.upsertMoodEntry(MoodEntry(date: DateTime(2025, 6, 4), timestamp: DateTime(2025, 6, 4), moodLevel: 3, emoji: ''));
    await pump(tester, GardenMonthScreen(month: DateTime(2025, 6, 4)));

    expect(find.text('2 plants, 1 flower'), findsOneWidget);
    expect(find.byType(PlantView), findsNWidgets(30));
    expect(find.text('A sprout: a bit of everything'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp(r'^5 June, nothing logged')));
    await tester.pumpAndSettle();
    expect(find.text('A quiet day'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('May 2025 garden'), findsOneWidget);
    expect(find.text('0 plants, 0 flowers'), findsOneWidget);
  });
}
