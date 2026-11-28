import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/features/tidy/presentation/tidy_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

/// Lets the database's real async work finish between frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

void main() {
  testWidgets('checks a range, ticks the fixes and applies them, at phone width', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = await openTestDatabase();
    addTearDown(closeTestDatabase);
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final day = DateTime(2026, 10, 14);
    final burger = await tester.runAsync(() => db.createMealEntry(MealEntry(date: day, time: DateTime(2026, 10, 14, 19), name: 'McSpicy')));
    final fries = await tester.runAsync(() => db.createMealEntry(MealEntry(date: day, time: DateTime(2026, 10, 14, 19, 2), name: 'Fries')));

    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: TidyScreen(start: day, end: day))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Fries → a side of McSpicy'), 200);
    expect(find.text('Fries → a side of McSpicy'), findsOneWidget);
    await tester.tap(find.text('Apply 1'));
    await settle(tester);
    final side = await tester.runAsync(() => db.getMealEntry(fries!));
    expect(side!.sideOf, burger);
    expect(find.text('Nothing to tidy. Nice.'), findsOneWidget);
  });
}
