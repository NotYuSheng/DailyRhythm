import 'package:daily_rhythm/features/exercise/data/models/exercise_entry.dart';
import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/features/metrics/data/models/metric_data.dart';
import 'package:daily_rhythm/features/metrics/presentation/screens/fact_detail_screen.dart';
import 'package:daily_rhythm/features/metrics/presentation/widgets/fun_facts_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_database.dart';

void main() {
  testWidgets('highlights swipe, favourite exercise opens the exercise breakdown, the rest are rows', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = await openTestDatabase();
    addTearDown(closeTestDatabase);
    for (var d = 1; d <= 20; d++) {
      final day = DateTime(2026, 10, d);
      await db.createMealEntry(MealEntry(date: day, time: day.add(const Duration(hours: 12)), name: 'Chicken rice', price: 4.5));
      if (d.isEven) await db.createExerciseEntry(ExerciseEntry(date: day, timestamp: day, type: ExerciseType.weightLifting, exerciseName: 'Push ups', reps: 40));
    }
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: FunFactsSection(range: DateRange.month(DateTime(2026, 10, 15), today: DateTime(2026, 10, 31)))))),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text('Go-to food'), findsOneWidget, reason: 'first highlight');
    expect(find.text('Food spending'), findsOneWidget, reason: 'a row below');

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Favourite exercise'), findsOneWidget);
    expect(find.text('Push ups'), findsOneWidget);

    await tester.tap(find.text('Push ups'));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(FactDetailScreen), findsOneWidget);
    expect(find.text('Your exercise'), findsOneWidget);
    expect(find.textContaining('kcal burned in all'), findsOneWidget);
  });
}
