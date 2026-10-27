import 'package:daily_rhythm/core/theme/app_theme.dart';
import 'package:daily_rhythm/features/metrics/presentation/screens/metrics_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_rhythm/shared/models/mood_entry.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_database.dart';

void main() {
  setUp(() async => openTestDatabase());
  tearDown(closeTestDatabase);

  testWidgets('every time range is on screen on a 360dp phone and selectable', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(theme: AppTheme.lightTheme, home: const MetricsScreen()),
    ));
    await tester.pumpAndSettle();

    const screenWidth = 360.0;
    for (final label in ['Week', 'Month', 'Year', 'All']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(0), reason: '$label starts off-screen');
      expect(rect.right, lessThanOrEqualTo(screenWidth), reason: '$label runs off-screen');
    }

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    expect(find.text('${DateTime.now().year}'), findsOneWidget);
  });

  testWidgets('arrows step back to the first entry and forward to today', (tester) async {
    final db = await openTestDatabase();
    final lastYear = DateTime.now().year - 1;
    await db.upsertMoodEntry(MoodEntry(date: DateTime(lastYear, 6, 1), timestamp: DateTime(lastYear, 6, 1), moodLevel: 3, emoji: ''));
    await tester.pumpWidget(ProviderScope(child: MaterialApp(theme: AppTheme.lightTheme, home: const MetricsScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();

    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull, reason: 'nothing after today');
    await tester.tap(find.byTooltip('Previous year'));
    await tester.pumpAndSettle();
    expect(find.text('$lastYear'), findsOneWidget);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left)).onPressed, isNull, reason: 'nothing before the first entry');
    await tester.tap(find.byTooltip('Next year'));
    await tester.pumpAndSettle();
    expect(find.text('${lastYear + 1}'), findsOneWidget);
  });
}
