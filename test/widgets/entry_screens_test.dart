import 'package:daily_rhythm/features/exercise/data/models/exercise_entry.dart';
import 'package:daily_rhythm/features/exercise/presentation/screens/add_exercise_screen.dart';
import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/features/meals/presentation/screens/add_meal_screen.dart';
import 'package:daily_rhythm/features/sleep/data/models/sleep_entry.dart';
import 'package:daily_rhythm/features/sleep/presentation/screens/add_sleep_screen.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

Widget _app(Widget screen) => ProviderScope(child: MaterialApp(home: screen));

Finder _field(String label) => find.widgetWithText(TextField, label);

void main() {
  late DatabaseService db;
  final pastDay = DateTime(2026, 10, 20);

  setUp(() async => db = await openTestDatabase());
  tearDown(closeTestDatabase);

  group('AddSleepScreen', () {
    testWidgets('saves a wake time on its own, picked from usual times', (tester) async {
      for (final d in [17, 18, 19]) {
        await db.saveSleepEntry(SleepEntry(date: DateTime(2026, 10, d), wakeUpTime: DateTime(2026, 10, d, 7, 32)));
      }
      await db.saveSleepEntry(SleepEntry(date: DateTime(2026, 10, 19), sleepTime: DateTime(2026, 10, 19, 23, 50)));
      await tester.pumpWidget(_app(AddSleepScreen(date: pastDay)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('07:30'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final entry = (await db.getSleepEntryByDate(pastDay))!;
      expect(entry.wakeUpTime, DateTime(2026, 10, 20, 7, 30));
      expect(entry.sleepTime, isNull);
      expect(entry.totalHours, closeTo(7.67, 0.01), reason: 'from the previous night\u2019s bedtime');
    });

    testWidgets('asks for at least one time', (tester) async {
      await tester.pumpWidget(_app(AddSleepScreen(date: pastDay)));
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Set when you woke up or went to bed'), findsOneWidget);
    });

    test('usual times are the most frequent, rounded, evening before night', () {
      final times = [
        for (final (h, m) in [(23, 50), (0, 5), (23, 55), (1, 10), (0, 2), (23, 46)]) DateTime(2026, 1, 1, h, m),
      ];
      expect(usualTimes(times).map((t) => (t.hour, t.minute)), [(23, 45), (0, 0), (1, 15)]);
    });
  });

  group('AddMealScreen', () {
    testWidgets('logs a meal without a price on the day it was opened for', (tester) async {
      await tester.pumpWidget(_app(AddMealScreen(date: pastDay)));
      await tester.enterText(_field('Meal Name'), 'Apple');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final meal = (await db.getAllMealEntries()).single;
      expect(meal.name, 'Apple');
      expect(meal.price, isNull);
      expect(meal.date, pastDay);
      expect(meal.time.day, pastDay.day);
    });

    testWidgets('rejects a non-numeric price', (tester) async {
      await tester.pumpWidget(_app(AddMealScreen(date: pastDay)));
      await tester.enterText(_field('Meal Name'), 'Rice');
      await tester.enterText(_field('Price (optional)'), 'abc');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Please enter a valid price'), findsOneWidget);
      expect(await db.getAllMealEntries(), isEmpty);
    });

    testWidgets('editing keeps the meal on its original day', (tester) async {
      final id = await db.createMealEntry(MealEntry(date: pastDay, time: DateTime(2026, 10, 20, 12), name: 'Noodles', price: 3.5));
      final entry = (await db.getAllMealEntries()).single;

      await tester.pumpWidget(_app(AddMealScreen(entry: entry)));
      await tester.enterText(_field('Meal Name'), 'Wanton noodles');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = (await db.getAllMealEntries()).single;
      expect(saved.id, id);
      expect(saved.name, 'Wanton noodles');
      expect(saved.date, pastDay);
    });
  });

  group('AddExerciseScreen', () {
    Future<void> openWeights(WidgetTester tester, Widget screen) async {
      await tester.pumpWidget(_app(screen));
      await tester.tap(find.text('Weights'));
      await tester.pumpAndSettle();
    }

    testWidgets('bodyweight sets save without a weight', (tester) async {
      await openWeights(tester, AddExerciseScreen(date: pastDay));
      await tester.tap(find.text('Bodyweight'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Exercise Name'), 'Situps');
      await tester.enterText(_field('Reps'), '60');
      await tester.enterText(_field('Sets'), '1');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = (await db.getAllExerciseEntries()).single;
      expect(saved.exerciseName, 'Situps');
      expect(saved.weight, isNull);
      expect(saved.date, pastDay);
    });

    testWidgets('weighted sets still require a weight', (tester) async {
      await openWeights(tester, AddExerciseScreen(date: pastDay));
      await tester.enterText(_field('Exercise Name'), 'Curl');
      await tester.enterText(_field('Reps'), '12');
      await tester.enterText(_field('Sets'), '3');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Please enter valid weight'), findsOneWidget);
      expect(await db.getAllExerciseEntries(), isEmpty);
    });

    testWidgets('editing a past entry does not move it to today', (tester) async {
      await db.createExerciseEntry(ExerciseEntry(
        date: pastDay,
        timestamp: DateTime(2026, 10, 20, 19),
        type: ExerciseType.run,
        runType: RunType.flat,
        distance: 5,
      ));
      final entry = (await db.getAllExerciseEntries()).single;

      await tester.pumpWidget(_app(AddExerciseScreen(entry: entry)));
      await tester.enterText(_field('Distance (km)'), '6');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = (await db.getAllExerciseEntries()).single;
      expect(saved.distance, 6);
      expect(saved.date, pastDay);
      expect(saved.timestamp, DateTime(2026, 10, 20, 19));
    });
  });
}
