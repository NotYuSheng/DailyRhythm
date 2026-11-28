import 'package:daily_rhythm/features/learning/data/learning_entry.dart';
import 'package:daily_rhythm/features/learning/data/learning_repository.dart';
import 'package:daily_rhythm/features/learning/presentation/add_learning_screen.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late DatabaseService db;
  setUp(() async => db = await openTestDatabase());
  tearDown(closeTestDatabase);
  final day = DateTime(2026, 11, 20);

  Widget app(Widget screen) => ProviderScope(child: MaterialApp(home: screen));

  Finder field(String label) => find.widgetWithText(TextField, label);

  testWidgets('one line is enough; the rest is kept when given', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(AddLearningScreen(date: day)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Say what you learnt, in a line'), findsOneWidget);

    await tester.enterText(field('What I learnt'), 'SQLite ALTER TABLE can\'t drop a column before 3.35');
    await tester.enterText(field('Topic (optional)'), 'Databases');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Deliberate'));
    await tester.tap(find.widgetWithText(ChoiceChip, '30m'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Hard'));
    await tester.tap(find.text('Reflect on it'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Now what?'), 'Keep migrations additive');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = (await LearningRepository(db).forDay(day)).single;
    expect(
      (saved.topic, saved.how, saved.minutes, saved.rpe, saved.soWhat, saved.nowWhat),
      ('Databases', LearningHow.deliberate, 30, 7, null, 'Keep migrations additive'),
    );
    expect(await LearningRepository(db).topics(), ['Databases']);
  });
}
