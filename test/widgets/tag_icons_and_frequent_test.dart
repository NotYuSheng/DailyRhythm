import 'package:daily_rhythm/features/garden/presentation/screens/activities_screen.dart';
import 'package:daily_rhythm/features/tags/data/models/tag.dart';
import 'package:daily_rhythm/features/tags/presentation/screens/tags_screen.dart';
import 'package:daily_rhythm/features/tags/presentation/tag_icons.dart';
import 'package:daily_rhythm/shared/models/activity_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/utils/date_utils.dart';
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

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: screen)));
    await tester.pumpAndSettle();
  }

  test('a picked icon wins over the one the name suggests', () {
    expect(tagIcon(Tag(name: 'Haircut', emoji: 'tag', category: '')), Icons.content_cut);
    expect(tagIcon(Tag(name: 'Haircut', emoji: '${pickedIconPrefix}spa', category: '')), Icons.spa_outlined);
    expect(tagIcon(Tag(name: 'Pottery', emoji: '${pickedIconPrefix}nonsense', category: '')), Icons.local_activity_outlined,
        reason: 'an unknown pick falls back');
  });

  testWidgets('a new tag can be given an icon, and set back to automatic', (tester) async {
    await pump(tester, const Scaffold(body: SizedBox()));
    showTagSheet(tester.element(find.byType(Scaffold)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Pottery');
    await tester.tap(find.bySemanticsLabel('art icon'));
    await tester.pump();
    expect(find.text('Your pick'), findsOneWidget);
    await tester.ensureVisible(find.text('Add tag'));
    await tester.tap(find.text('Add tag'));
    await tester.pumpAndSettle();
    final pottery = (await db.getAllTags()).singleWhere((t) => t.name == 'Pottery');
    expect(pottery.emoji, '${pickedIconPrefix}art');

    showTagSheet(tester.element(find.byType(Scaffold)), tag: pottery);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auto'));
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await db.getAllTags()).singleWhere((t) => t.name == 'Pottery').emoji, 'tag');
  });

  testWidgets('tags picked on many recent days come first and stand out', (tester) async {
    final tags = {for (final t in await db.getAllTags()) t.name: t.id!};
    final today = dayOf(DateTime.now());
    for (var i = 1; i <= 20; i++) {
      final day = today.subtract(Duration(days: i));
      await db.createActivityEntry(ActivityEntry(date: day, timestamp: day, tagId: tags['Video Games']!));
    }
    await pump(tester, ActivitiesScreen(day: today));
    FilterChip chip(String name) => tester.widget<FilterChip>(find.widgetWithText(FilterChip, name));
    expect(chip('Video Games').backgroundColor, isNotNull, reason: 'used on 20 of the last 56 days');
    expect(chip('Draw').backgroundColor, isNull);
    final order = [for (final c in tester.widgetList<FilterChip>(find.byType(FilterChip))) ((c.label as Text).data)];
    expect(order.indexOf('Video Games'), lessThan(order.indexOf('Watch Videos')), reason: 'first in its group');
  });
}
