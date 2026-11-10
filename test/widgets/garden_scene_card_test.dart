import 'package:daily_rhythm/features/garden/presentation/screens/garden_month_screen.dart';
import 'package:daily_rhythm/features/garden/presentation/screens/year_gardens_screen.dart';
import 'package:daily_rhythm/features/metrics/data/models/metric_data.dart';
import 'package:daily_rhythm/features/metrics/presentation/widgets/garden_motion.dart';
import 'package:daily_rhythm/features/metrics/presentation/widgets/garden_scene_card.dart';
import 'package:daily_rhythm/shared/models/mood_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_database.dart';

void main() {
  late DatabaseService db;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await openTestDatabase();
  });
  tearDown(closeTestDatabase);

  Future<void> pump(WidgetTester tester, DateRange range) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: GardenSceneCard(range: range))))));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
  }

  testWidgets('a month shows its plants and opens its calendar', (tester) async {
    stillGarden(tester);
    for (final d in [3, 4, 5]) {
      await db.upsertMoodEntry(MoodEntry(date: DateTime(2026, 10, d), timestamp: DateTime(2026, 10, d, 21), moodLevel: 4, emoji: ''));
    }
    await pump(tester, DateRange.month(DateTime(2026, 10, 15)));
    expect(find.text('October’s garden'), findsOneWidget);
    expect(find.textContaining('3 of 31 days logged'), findsOneWidget);
    expect(find.textContaining('· 100%', findRichText: true), findsOneWidget, reason: 'each kind of day with its share');
    await tester.tap(find.byType(GardenSceneCard));
    await tester.pumpAndSettle();
    expect(find.byType(GardenMonthScreen), findsOneWidget);
  });

  testWidgets('the garden moves gently, and stands still with reduced motion', (tester) async {
    await db.upsertMoodEntry(MoodEntry(date: DateTime(2026, 10, 3), timestamp: DateTime(2026, 10, 3, 21), moodLevel: 4, emoji: ''));
    await pump(tester, DateRange.month(DateTime(2026, 10, 15)));
    expect(find.byType(GardenMotion), findsOneWidget);
    Matrix4 lean() => tester.widget<Transform>(find.descendant(of: find.byType(GardenMotion), matching: find.byType(Transform)).first).transform;
    final before = lean().clone();
    await tester.pump(const Duration(milliseconds: 900));
    expect(lean(), isNot(before), reason: 'the plants sway');
    await tester.pumpWidget(const SizedBox());

    stillGarden(tester);
    await pump(tester, DateRange.month(DateTime(2026, 10, 15)));
    expect(find.byType(GardenMotion), findsNothing);
  });

  testWidgets('a year opens the year of gardens; an empty one says so', (tester) async {
    stillGarden(tester);
    await pump(tester, DateRange.year(DateTime(2025, 6, 1)));
    expect(find.text('Nothing grew in this period yet.'), findsOneWidget);
    await tester.tap(find.byType(GardenSceneCard));
    await tester.pumpAndSettle();
    expect(find.byType(YearGardensScreen), findsOneWidget);
  });
}

/// The garden scene moves forever; tests see it still, as with reduced
/// motion, so pumpAndSettle can settle.
void stillGarden(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}
