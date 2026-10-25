import 'package:daily_rhythm/features/exercise/presentation/screens/add_exercise_screen.dart';
import 'package:daily_rhythm/features/journal/presentation/screens/journal_screen.dart';
import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/features/meals/presentation/screens/add_meal_screen.dart';
import 'package:daily_rhythm/main.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_database.dart';

void main() {
  late DatabaseService db;
  final pastDay = DateTime(2026, 10, 20);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await openTestDatabase();
  });
  tearDown(closeTestDatabase);

  Future<void> pumpJournal(WidgetTester tester, DateTime day) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: JournalScreen(initialDate: day)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('app starts on today\u2019s plant, with the journal one tab away', (tester) async {
    // The plant sways unless reduced motion is on; tests can't settle on a loop.
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(const ProviderScope(child: DailyRhythmApp()));
    await tester.pumpAndSettle();
    expect(find.text('Today\u2019s plant'), findsOneWidget);

    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    expect(find.text('DailyRhythm'), findsOneWidget);
    expect(find.text('Mood'), findsOneWidget);
  });

  testWidgets('tapping a mood saves it for the day being viewed', (tester) async {
    await pumpJournal(tester, pastDay);
    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();

    final mood = await db.getMoodEntryByDate(pastDay);
    expect(mood!.moodLevel, 4);
    expect(await db.getMoodEntryByDate(DateTime.now()), isNull);
  });

  testWidgets('shows meals logged for that day, including unpriced ones', (tester) async {
    await db.createMealEntry(MealEntry(date: pastDay, time: DateTime(2026, 10, 20, 12), name: 'Chicken rice', price: 4));
    await db.createMealEntry(MealEntry(date: pastDay, time: DateTime(2026, 10, 20, 16), name: 'Apple'));
    await pumpJournal(tester, pastDay);

    expect(find.text('Chicken rice'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('\$4.00'), findsWidgets);
  });

  testWidgets('add screens open for the day being viewed, not today', (tester) async {
    await pumpJournal(tester, pastDay);

    await tester.tap(find.text('Meals'));
    await tester.pumpAndSettle();
    expect(tester.widget<AddMealScreen>(find.byType(AddMealScreen)).date, pastDay);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Exercise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exercise'));
    await tester.pumpAndSettle();
    expect(tester.widget<AddExerciseScreen>(find.byType(AddExerciseScreen)).date, pastDay);
  });
}
