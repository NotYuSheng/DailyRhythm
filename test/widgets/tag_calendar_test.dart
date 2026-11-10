import 'package:daily_rhythm/features/tags/presentation/screens/tag_calendar_screen.dart';
import 'package:daily_rhythm/shared/models/activity_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/utils/date_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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

  testWidgets('a tag\'s days show on its calendar, opening on the month it was last used', (tester) async {
    final tag = (await db.getAllTags()).firstWhere((t) => t.name == 'Haircut');
    final today = dayOf(DateTime.now());
    final lastMonth = DateTime(today.year, today.month - 1, 12);
    for (final d in [DateTime(today.year, today.month - 3, 2), lastMonth]) {
      await db.createActivityEntry(ActivityEntry(date: d, timestamp: d, tagId: tag.id!));
    }
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: TagCalendarScreen(tag: tag))));
    await tester.pumpAndSettle();

    expect(find.text('Haircut'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('days in all'), findsOneWidget);
    expect(find.text(DateFormat('MMMM y').format(lastMonth)), findsOneWidget, reason: 'opens on the last month it was used');
    expect(find.bySemanticsLabel('${DateFormat('EEEE d MMMM').format(lastMonth)}, tagged'), findsOneWidget);
    expect(find.text('1 day'), findsOneWidget, reason: 'that month');

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text(DateFormat('MMMM y').format(DateTime(today.year, today.month - 3))), findsOneWidget);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_back)).onPressed, isNull, reason: 'nothing before the first use');
  });
}
