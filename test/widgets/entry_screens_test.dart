import 'package:daily_rhythm/features/exercise/data/models/exercise_entry.dart';
import 'package:daily_rhythm/features/exercise/data/models/exercise_item.dart';
import 'package:daily_rhythm/features/exercise/presentation/screens/add_exercise_screen.dart';
import 'package:daily_rhythm/features/meals/data/models/food_item.dart';
import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/features/meals/data/providers/meal_providers.dart';
import 'package:daily_rhythm/features/meals/data/services/calorie_lookup.dart';
import 'package:daily_rhythm/shared/services/database/repositories/catalog_repository.dart';
import 'package:daily_rhythm/features/meals/presentation/screens/add_meal_screen.dart';
import 'package:daily_rhythm/features/sleep/data/models/sleep_entry.dart';
import 'package:daily_rhythm/features/sleep/presentation/screens/add_sleep_screen.dart';
import 'package:daily_rhythm/shared/models/spending_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/services/database/repositories/spending_repository.dart';
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

    test('bedtime offers rounded times just after now', () {
      String fmt(TimeOfDay t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
      expect(laterTimes(DateTime(2026, 1, 1, 23, 7)).map(fmt), ['23:10', '23:15', '23:30', '23:45']);
      expect(laterTimes(DateTime(2026, 1, 1, 23, 10)).map(fmt), ['23:15', '23:30', '23:45', '0:00'],
          reason: 'strictly after now, wrapping past midnight');
      expect(laterTimes(DateTime(2026, 1, 1, 22, 58)).map(fmt), ['23:00', '23:15', '23:30', '23:45']);
    });

    test('usual times are the most frequent, rounded, evening before night', () {
      final times = [
        for (final (h, m) in [(23, 50), (0, 5), (23, 55), (1, 10), (0, 2), (23, 46)]) DateTime(2026, 1, 1, h, m),
      ];
      expect(usualTimes(times).map((t) => (t.hour, t.minute)), [(23, 45), (0, 0), (1, 15)]);
    });
  });

  group('AddMealScreen', () {
    Future<void> seedFoods(DatabaseService db) async {
      final catalog = CatalogRepository(db);
      final maggi = await catalog.saveFood(FoodItem(name: 'Maggi', aliases: ['Maggie'], lastPrice: 1.2));
      final rice = await catalog.saveFood(FoodItem(name: 'Mixed rice', aliases: ['Cai peng'], lastPrice: 4.5));
      for (final (d, id, name) in [(18, rice, 'Mixed rice'), (19, rice, 'Mixed rice'), (19, maggi, 'Maggi')]) {
        await db.createMealEntry(MealEntry(date: DateTime(2026, 10, d), time: DateTime(2026, 10, d, 12), name: name, foodItemId: id));
      }
    }

    testWidgets('offers usual foods and fills the last price', (tester) async {
      await seedFoods(db);
      await tester.pumpWidget(_app(AddMealScreen(date: pastDay)));
      await tester.pumpAndSettle();
      expect(find.text('Your usual'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Mixed rice'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'Mixed rice'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_field('Meal Name')).controller!.text, 'Mixed rice');
      expect(tester.widget<TextField>(_field('Price (optional)')).controller!.text, '4.50');
    });

    testWidgets('shows how healthy a meal is while typing it', (tester) async {
      await tester.pumpWidget(_app(AddMealScreen(date: pastDay)));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Meal Name'), 'Fried rice');
      await tester.pumpAndSettle();
      expect(find.text('Health 2/5 · fried'), findsOneWidget);
    });

    testWidgets('suggests foods while typing and offers the agreed spelling', (tester) async {
      await seedFoods(db);
      await tester.pumpWidget(_app(AddMealScreen(date: pastDay)));
      await tester.pumpAndSettle();

      await tester.enterText(_field('Meal Name'), 'cai');
      await tester.pump();
      expect(find.widgetWithText(ListTile, 'Mixed rice'), findsOneWidget);

      await tester.enterText(_field('Meal Name'), 'maggie');
      await tester.pump();
      expect(find.text('Did you mean Maggi?', findRichText: true), findsOneWidget);
      await tester.tap(find.text('Use it'));
      await tester.pump();
      expect(tester.widget<TextField>(_field('Meal Name')).controller!.text, 'Maggi');
    });

    testWidgets('saves a typed alias under the agreed name, linked to the food', (tester) async {
      await seedFoods(db);
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(AddMealScreen(date: pastDay)));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Meal Name'), 'cai peng');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Food court'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final meal = (await db.getMealEntriesByDate(pastDay)).single;
      final rice = await CatalogRepository(db).findFood('Mixed rice');
      expect((meal.name, meal.foodItemId, meal.foodSource), ('Mixed rice', rice!.id, FoodSource.foodCourt));
    });

    testWidgets('what\'s in a meal can be ticked, for the food or just this meal', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(AddMealScreen(date: pastDay)));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Meal Name'), 'Mixed rice');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Health 3/5 · a typical plate'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'vegetables'));
      await tester.pumpAndSettle();
      expect(find.text('Health 4/5 · vegetables'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final rice = (await CatalogRepository(db).findFood('Mixed rice'))!;
      expect(rice.healthTags, ['vegetables'], reason: 'remembered for the food');
      expect((await db.getMealEntriesByDate(pastDay)).single.healthTags, isNull);

      // Another day, just that meal: fried.
      final other = DateTime(pastDay.year, pastDay.month, pastDay.day - 1);
      await tester.pumpWidget(const SizedBox()); // saving closed the screen: start a new app
      await tester.pumpWidget(_app(AddMealScreen(date: other)));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Meal Name'), 'Mixed rice');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Health 4/5 · vegetables'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'vegetables'));
      await tester.tap(find.widgetWithText(FilterChip, 'fried'));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Only this meal'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect((await db.getMealEntriesByDate(other)).single.healthTags, ['fried']);
      expect((await CatalogRepository(db).findFood('Mixed rice'))!.healthTags, ['vegetables'], reason: 'the food keeps its own');
    });

    testWidgets('typed calories become the food\'s, per serving', (tester) async {
      await tester.pumpWidget(_app(AddMealScreen(date: pastDay)));
      await tester.enterText(_field('Meal Name'), 'Laksa');
      await tester.enterText(_field('Qty'), '2');
      await tester.enterText(_field('Calories (optional)'), '1100');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final laksa = (await CatalogRepository(db).findFood('Laksa'))!;
      expect((laksa.kcal, laksa.kcalSource), (550.0, 'user'));
    });

    testWidgets('a known food\'s calories show as the default; a lookup fills them', (tester) async {
      await CatalogRepository(db).saveFood(FoodItem(name: 'Maggi', kcal: 380, kcalSource: 'off'));
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [calorieLookupProvider.overrideWithValue(_FakeLookup())],
        child: MaterialApp(home: AddMealScreen(date: pastDay)),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Meal Name'), 'Maggi');
      await tester.pumpAndSettle();
      expect(find.text('≈ 380 from Maggi'), findsOneWidget);

      await tester.enterText(_field('Meal Name'), 'Mee goreng');
      await tester.pump();
      await tester.tap(find.text('Look up calories'));
      await tester.pumpAndSettle();
      expect(find.text('From Open Food Facts (ODbL). Estimates, not nutrition advice.'), findsOneWidget);
      await tester.tap(find.text('Fried noodles'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_field('Calories (optional)')).controller!.text, '510');
      await tester.enterText(_field('Qty'), '2');
      await tester.pump();
      expect(tester.widget<TextField>(_field('Calories (optional)')).controller!.text, '1020');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final food = (await CatalogRepository(db).findFood('Mee goreng'))!;
      expect((food.kcal, food.kcalSource), (510.0, 'off'));
    });

    testWidgets('editing an old meal doesn\'t change its food\'s calories', (tester) async {
      final maggi = await CatalogRepository(db).saveFood(FoodItem(name: 'Maggi', kcal: 380, kcalSource: 'off'));
      await db.createMealEntry(MealEntry(date: pastDay, time: DateTime(2026, 10, 20, 12), name: 'Maggi', calories: 500, foodItemId: maggi));
      final meal = (await db.getMealEntriesByDate(pastDay)).single;
      await tester.pumpWidget(_app(AddMealScreen(entry: meal)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final food = (await CatalogRepository(db).findFood('Maggi'))!;
      expect((food.kcal, food.kcalSource), (380.0, 'off'));
    });

    testWidgets('editing an old meal never gives its food an estimate', (tester) async {
      await CatalogRepository(db).saveFood(FoodItem(name: 'Laksa', kcal: 590, kcalSource: 'user'));
      final rebus = await CatalogRepository(db).saveFood(FoodItem(name: 'Spicy laksa'));
      await db.createMealEntry(MealEntry(date: pastDay, time: DateTime(2026, 10, 20, 12), name: 'Spicy laksa', foodItemId: rebus));
      final meal = (await db.getMealEntriesByDate(pastDay)).single;
      await tester.pumpWidget(_app(AddMealScreen(entry: meal)));
      await tester.pumpAndSettle();
      expect(find.textContaining('An estimate'), findsNothing);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect((await CatalogRepository(db).findFood('Spicy laksa'))!.kcal, isNull);
    });

    testWidgets('a quantity of 0 isn\'t saved', (tester) async {
      await tester.pumpWidget(_app(AddMealScreen(date: pastDay)));
      await tester.enterText(_field('Meal Name'), 'Laksa');
      await tester.enterText(_field('Qty'), '0');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Quantity must be at least 1'), findsOneWidget);
      expect(await db.getMealEntriesByDate(pastDay), isEmpty);
    });

    testWidgets('an imported meal can move to events & gifts', (tester) async {
      await db.createMealEntry(MealEntry(
          date: pastDay, time: DateTime(2026, 10, 20, 12), name: 'Farewell hotpot', price: 64.5, rawText: 'farewell hotpot 64.50', timeKnown: false));
      final meal = (await db.getMealEntriesByDate(pastDay)).single;
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => AddMealScreen(entry: meal)))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not a meal: move to events & gifts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move'));
      await tester.pumpAndSettle();
      expect(find.text('Edit event or gift'), findsOneWidget);
      expect(await db.getMealEntriesByDate(pastDay), isEmpty);
      final moved = (await SpendingRepository(db).forDay(pastDay)).single;
      expect((moved.label, moved.amount, moved.rawText, moved.time), ('Farewell hotpot', 64.5, 'farewell hotpot 64.50', null),
          reason: 'an imported placeholder time is not passed on');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Gift'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect((await SpendingRepository(db).forDay(pastDay)).single.category, SpendingEntry.gift);
    });

    testWidgets('a new food starts with an estimate, which typing replaces', (tester) async {
      await CatalogRepository(db).saveFood(FoodItem(name: 'Laksa', kcal: 590, kcalSource: 'user'));
      await db.createMealEntry(MealEntry(date: DateTime(2026, 10, 1), time: DateTime(2026, 10, 1, 12), name: 'Laksa'));
      await tester.pumpWidget(_app(AddMealScreen(date: pastDay)));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Meal Name'), 'Spicy laksa');
      await tester.pump();
      expect(find.text('An estimate, like your Laksa. Type your own to change it.'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final food = (await CatalogRepository(db).findFood('Spicy laksa'))!;
      expect((food.kcal, food.kcalSource), (590.0, 'estimate'));
    });

    testWidgets('a new food joins the catalog with its price', (tester) async {
      await tester.pumpWidget(_app(AddMealScreen(date: pastDay)));
      await tester.enterText(_field('Meal Name'), 'Laksa');
      await tester.enterText(_field('Price (optional)'), '6');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final laksa = await CatalogRepository(db).findFood('laksa');
      expect((laksa?.name, laksa?.lastPrice), ('Laksa', 6.0));
    });

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
      // Tall enough that usual chips and suggestions don't scroll the form
      // out of the lazily built list.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(screen));
      await tester.pumpAndSettle();
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

    Future<void> seedExercises(DatabaseService db) async {
      final catalog = CatalogRepository(db);
      final pushups = await catalog.saveExercise(ExerciseItem(name: 'Push ups', aliases: ['pushups']));
      final run = await catalog.saveExercise(ExerciseItem(name: 'Run', category: ExerciseItem.cardio));
      for (final d in [17, 18, 19]) {
        await db.createExerciseEntry(ExerciseEntry(
          date: DateTime(2026, 10, d), timestamp: DateTime(2026, 10, d, 19), type: ExerciseType.weightLifting,
          exerciseName: 'Push ups', equipmentType: EquipmentType.bodyweight, reps: 20 + d - 17, sets: 3,
          exerciseItemId: pushups,
        ));
      }
      await db.createExerciseEntry(ExerciseEntry(
        date: DateTime(2026, 10, 18), timestamp: DateTime(2026, 10, 18, 7), type: ExerciseType.run,
        runType: RunType.flat, distance: 5.2, duration: const Duration(minutes: 31), exerciseItemId: run,
      ));
    }

    testWidgets('a usual exercise is one tap plus Save, prefilled from last time', (tester) async {
      await seedExercises(db);
      await tester.pumpWidget(_app(AddExerciseScreen(date: pastDay)));
      await tester.pumpAndSettle();
      expect(find.text('Your usual'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'Push ups'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = (await db.getExerciseEntriesByDate(pastDay)).single;
      final item = await CatalogRepository(db).findExercise('Push ups');
      expect((saved.exerciseName, saved.reps, saved.sets, saved.equipmentType), ('Push ups', 22, 3, EquipmentType.bodyweight));
      expect(saved.exerciseItemId, item!.id);
    });

    testWidgets('a usual run comes back as a run with its distance', (tester) async {
      await seedExercises(db);
      await tester.pumpWidget(_app(AddExerciseScreen(date: pastDay)));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Run'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_field('Distance (km)')).controller!.text, '5.2');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = (await db.getExerciseEntriesByDate(pastDay)).single;
      expect((saved.type, saved.distance, saved.duration), (ExerciseType.run, 5.2, const Duration(minutes: 31)));
    });

    testWidgets('suggests exercises while typing and corrects an alias', (tester) async {
      await seedExercises(db);
      await openWeights(tester, AddExerciseScreen(date: pastDay));
      await tester.enterText(_field('Exercise Name'), 'pus');
      await tester.pump();
      expect(find.widgetWithText(ListTile, 'Push ups'), findsOneWidget);

      await tester.enterText(_field('Exercise Name'), 'pushups');
      await tester.pump();
      expect(find.text('Did you mean Push ups?', findRichText: true), findsOneWidget);
    });

    testWidgets('a typed alias saves under the catalog name', (tester) async {
      await seedExercises(db);
      await openWeights(tester, AddExerciseScreen(date: pastDay));
      await tester.tap(find.text('Bodyweight'));
      await tester.pumpAndSettle();
      // Amounts first: suggestions under the name push them down the list.
      await tester.enterText(_field('Reps'), '15');
      await tester.enterText(_field('Sets'), '2');
      await tester.enterText(_field('Exercise Name'), 'pushups');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect((await db.getExerciseEntriesByDate(pastDay)).single.exerciseName, 'Push ups');
    });

    testWidgets('a new exercise joins the catalog', (tester) async {
      await seedExercises(db);
      await openWeights(tester, AddExerciseScreen(date: pastDay));
      await tester.tap(find.text('Bodyweight'));
      await tester.pumpAndSettle();
      // Amounts first: suggestions under the name push them down the list.
      await tester.enterText(_field('Reps'), '10');
      await tester.enterText(_field('Sets'), '1');
      await tester.enterText(_field('Exercise Name'), 'Burpees');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final burpees = await CatalogRepository(db).findExercise('burpees');
      expect(burpees, isNotNull);
      expect((await db.getExerciseEntriesByDate(pastDay)).map((e) => e.exerciseItemId), contains(burpees!.id));
    });

    testWidgets('picking an exercise keeps amounts already typed', (tester) async {
      await seedExercises(db);
      await openWeights(tester, AddExerciseScreen(date: pastDay));
      await tester.enterText(_field('Reps'), '15');
      await tester.tap(find.widgetWithText(ActionChip, 'Push ups'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_field('Reps')).controller!.text, '15');
      expect(tester.widget<TextField>(_field('Sets')).controller!.text, '');
    });

    testWidgets('switching to Run drops a weights exercise name', (tester) async {
      await seedExercises(db);
      await openWeights(tester, AddExerciseScreen(date: pastDay));
      await tester.enterText(_field('Exercise Name'), 'Push ups');
      await tester.tap(find.descendant(of: find.byType(SegmentedButton<ExerciseType>), matching: find.text('Run')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_field('Exercise Name')).controller!.text, '');
    });

    testWidgets('editing keeps an imported entry\'s catalog link', (tester) async {
      final bench = await CatalogRepository(db).saveExercise(ExerciseItem(name: 'Bench press'));
      await db.createExerciseEntry(ExerciseEntry(
        date: pastDay, timestamp: DateTime(2026, 10, 20, 19), type: ExerciseType.weightLifting,
        exerciseName: 'chest day', equipmentType: EquipmentType.barbell, reps: 8, weight: 60, sets: 3,
        exerciseItemId: bench, rawText: 'chest day 3x8 60kg',
      ));
      final entry = (await db.getAllExerciseEntries()).single;
      await tester.pumpWidget(_app(AddExerciseScreen(entry: entry)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = (await db.getAllExerciseEntries()).single;
      expect((saved.exerciseItemId, saved.rawText), (bench, 'chest day 3x8 60kg'));
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

class _FakeLookup implements CalorieLookup {
  @override
  Future<List<CalorieMatch>> search(String query) async =>
      [const CalorieMatch(name: 'Fried noodles', kcal: 510, basis: 'serving', source: 'off')];
}
