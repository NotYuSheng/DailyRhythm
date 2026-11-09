// Store screenshots: seeds made-up sample data, opens the real app on a
// 1080 × 2340 phone with the app's fonts, and saves each screen as a PNG.
//
//   flutter test tool/store_listing/screenshots_test.dart --update-goldens
//
// The PNGs land in tool/store_listing/raw/; frame.html adds the captions.
// Nothing here is anyone's real journal.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:math';

import 'package:daily_rhythm/features/exercise/data/models/exercise_entry.dart';
import 'package:daily_rhythm/features/garden/presentation/screens/garden_today_screen.dart';
import 'package:daily_rhythm/features/journal/data/models/journal_entry.dart';
import 'package:daily_rhythm/features/meals/data/models/food_item.dart';
import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/features/metrics/presentation/widgets/fun_facts_section.dart';
import 'package:daily_rhythm/features/sleep/data/models/sleep_entry.dart';
import 'package:daily_rhythm/main.dart';
import 'package:daily_rhythm/shared/models/activity_entry.dart';
import 'package:daily_rhythm/shared/models/mood_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/services/database/repositories/catalog_repository.dart';
import 'package:daily_rhythm/shared/services/database/repositories/checkin_repository.dart';
import 'package:daily_rhythm/shared/services/database/repositories/journal_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/helpers/test_database.dart';

const _foods = [
  ('Kaya toast', 380.0, 2.8), ('Oatmeal with berries', 320.0, 0.0), ('Chicken rice', 650.0, 5.0), ('Laksa', 600.0, 6.5),
  ('Salad bowl', 420.0, 11.9), ('Fish soup', 400.0, 6.0), ('Nasi lemak', 640.0, 4.5), ('Dumplings', 450.0, 7.0),
  ('Mee goreng', 620.0, 5.5), ('Yong tau foo', 350.0, 6.8), ('Banana', 105.0, 0.0), ('Pasta', 700.0, 14.0),
];
const _moments = [
  ('Picnic by the reservoir with friends', 5), ('Finished the big presentation!', 5), ('Long call with grandma', 4),
  ('Tried a new laksa place, so good', 4), ('Rainy day, stayed in and read', 3), ('First 5 km run without stopping', 5),
];

Future<void> _font(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  await (FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
}

/// About ten weeks of a plausible life, ending today.
Future<void> _seed(DatabaseService db, DateTime today) async {
  final r = Random(11);
  final catalog = CatalogRepository(db);
  final foodIds = <String, int>{};
  for (final (name, kcal, _) in _foods) {
    foodIds[name] = await catalog.saveFood(FoodItem(name: name, kcal: kcal, kcalSource: 'estimate'));
  }
  final tags = {for (final t in await db.getAllTags()) t.name: t.id!};
  final checkins = CheckinRepository(db);
  for (var back = 70; back >= 0; back--) {
    final day = DateTime(today.year, today.month, today.day - back);
    // A few quiet days, never at a month's end (the calendar opens there).
    final lastOfMonth = DateTime(day.year, day.month + 1, 0).day == day.day;
    if (back > 0 && !lastOfMonth && r.nextDouble() < 0.05) continue;
    final weekend = day.weekday >= 6;
    await db.saveSleepEntry(SleepEntry(
      date: day,
      wakeUpTime: day.add(Duration(hours: weekend ? 8 : 7, minutes: r.nextInt(50))),
      sleepTime: back == 0 ? null : day.add(Duration(hours: 23, minutes: r.nextInt(70))),
    ));
    await db.upsertMoodEntry(MoodEntry(date: day, timestamp: day.add(const Duration(hours: 21)), moodLevel: [3, 4, 4, 4, 5, 3, 2][r.nextInt(7)], emoji: ''));
    final meals = back == 0 ? [0, 2] : [r.nextInt(2) == 0 ? 0 : 1, 2 + r.nextInt(5), 6 + r.nextInt(6)];
    for (final (i, f) in meals.indexed) {
      final (name, _, price) = _foods[f.clamp(0, _foods.length - 1)];
      await db.createMealEntry(MealEntry(
        date: day,
        time: day.add(Duration(hours: 8 + i * 5)),
        name: name,
        price: price == 0 ? null : price,
        foodItemId: foodIds[name],
      ));
    }
    if (r.nextDouble() < 0.55 || back == 0) {
      final run = r.nextBool();
      await db.createExerciseEntry(run
          ? ExerciseEntry(date: day, timestamp: day.add(const Duration(hours: 18)), type: ExerciseType.run, distance: 3 + r.nextInt(4).toDouble(), exerciseName: 'Run')
          : ExerciseEntry(date: day, timestamp: day.add(const Duration(hours: 18)), type: ExerciseType.weightLifting, exerciseName: ['Push ups', 'Squats', 'Plank'][r.nextInt(3)], reps: 20 + r.nextInt(30), sets: 3));
    }
    // One main thing most days, so the garden shows every kind of plant.
    const kinds = ['Work', 'Work', 'Study', 'Social Event', 'Family Time', 'Video Games', 'Watch Videos', 'Exercise', 'Nap'];
    final dayTags = <String>{
      if (back == 0) 'Exercise' else kinds[r.nextInt(kinds.length)],
      if (back == 0 || r.nextDouble() < 0.1) 'Change Bedsheets',
    };
    for (final t in dayTags) {
      if (tags[t] case final id?) await db.createActivityEntry(ActivityEntry(date: day, timestamp: day, tagId: id));
    }
    if (back % 11 == 3 || back == 0) {
      final (text, mood) = _moments[back == 0 ? 1 : (back ~/ 11) % _moments.length];
      await JournalRepository(db).save(JournalEntry(date: day, time: day.add(const Duration(hours: 20)), text: text, mood: mood));
    }
    if (back <= 2) await checkins.update(day, energy: 1, stress: -1, focus: 1);
  }
}

void main() {
  setUpAll(() async {
    await _font('Nunito', 'assets/fonts/Nunito-Variable.ttf');
    await _font('MaterialIcons', '${Platform.environment['FLUTTER_ROOT'] ?? '/home/ubuntu/snap/flutter/common/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  });

  testWidgets('store screenshots', (tester) async {
    SharedPreferences.setMockInitialValues({'profile_birth_year': 1996, 'profile_height_cm': 172.0, 'profile_weight_kg': 64.0});
    final db = await openTestDatabase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    GardenTodayScreen.clock = () => today.add(const Duration(hours: 19));
    await _seed(db, today);

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    Future<void> settle() async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> shoot(String name) async {
      await settle();
      await expectLater(find.byType(Scaffold).first, matchesGoldenFile('raw/$name.png'));
    }

    /// Scrolls [target] to just below the top of the screen.
    Future<void> toTop(Finder target, {double dy = 300}) async {
      await tester.scrollUntilVisible(target, dy, scrollable: find.byType(Scrollable).hitTestable().first);
      await tester.runAsync(() => Scrollable.ensureVisible(tester.element(target), alignment: 0.02));
      await settle();
    }

    await tester.pumpWidget(const ProviderScope(child: DailyRhythmApp()));
    await shoot('1_today');

    await toTop(find.text('Your day'));
    await shoot('2_your_day');

    // Last month: a full garden.
    await tester.tap(find.text('Garden').last);
    await settle();
    await tester.tap(find.byIcon(Icons.arrow_back).hitTestable().first);
    await shoot('3_garden');

    await tester.tap(find.text('Metrics').last);
    await settle();
    await tester.tap(find.byTooltip('Previous month'));
    await shoot('4_metrics');

    await toTop(find.byType(FunFactsSection));
    await shoot('5_fun_facts');

    await tester.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, 3000));
    await settle();
    await tester.tap(find.text('Year'));
    await shoot('6_year');

    GardenTodayScreen.clock = DateTime.now;
    await closeTestDatabase();
  });
}
