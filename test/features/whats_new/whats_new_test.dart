import 'package:daily_rhythm/features/meals/data/models/meal_entry.dart';
import 'package:daily_rhythm/features/whats_new/release_notes.dart';
import 'package:daily_rhythm/features/whats_new/whats_new_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(closeTestDatabase);

  test('a first install has nothing to catch up on', () async {
    final db = await openTestDatabase();
    expect(await WhatsNewScreen.unseen(db), isEmpty);
    expect((await SharedPreferences.getInstance()).getString(WhatsNewScreen.seenKey), releaseNotes.first.version);
  });

  test('an update shows the notes once', () async {
    final db = await openTestDatabase();
    await db.createMealEntry(MealEntry(date: DateTime(2026, 11, 1), time: DateTime(2026, 11, 1, 12), name: 'Laksa'));
    expect(await WhatsNewScreen.unseen(db), releaseNotes);
    await WhatsNewScreen.markSeen();
    expect(await WhatsNewScreen.unseen(db), isEmpty);
  });

  testWidgets('fits a phone, and Later puts it away', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 760 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const WhatsNewScreen())),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Later'), 200);
    expect(find.text('Update my data with AI'), findsOneWidget);
    await tester.ensureVisible(find.text('Later'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Later'));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pumpAndSettle();
    }
    expect(find.text('open'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString(WhatsNewScreen.seenKey), releaseNotes.first.version);
  });
}
