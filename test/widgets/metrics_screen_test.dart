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
    expect(find.text('Every day of the year'), findsNothing, reason: 'nothing logged this year');
    await tester.tap(find.byTooltip('Previous year'));
    await tester.pumpAndSettle();
    expect(find.text('$lastYear'), findsOneWidget);
    // A year's own view: every day, mood and sleep by month, a row per month.
    expect(find.text('Every day of the year'), findsOneWidget);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Month by month'), 300, scrollable: scrollable);
    await tester.scrollUntilVisible(find.byTooltip('Next year'), -300, scrollable: scrollable);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left)).onPressed, isNull, reason: 'nothing before the first entry');
    await tester.tap(find.byTooltip('Next year'));
    await tester.pumpAndSettle();
    expect(find.text('${lastYear + 1}'), findsOneWidget);
  });

  testWidgets('every period has its overview, grouped to fit', (tester) async {
    final db = await openTestDatabase();
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    await db.upsertMoodEntry(MoodEntry(date: day, timestamp: day, moodLevel: 4, emoji: ''));
    await tester.pumpWidget(ProviderScope(child: MaterialApp(theme: AppTheme.lightTheme, home: const MetricsScreen())));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    for (final (period, grid, mood, table) in [
      ('Week', 'Every day of the week', 'Mood by day', 'Day by day'),
      ('Month', 'Every day of the month', 'Mood by week', 'Week by week'),
      ('Year', 'Every day of the year', 'Mood by month', 'Month by month'),
      ('All', 'Every week since you started', 'Mood by year', 'Year by year'),
    ]) {
      await tester.scrollUntilVisible(find.text(period), -300, scrollable: scrollable);
      await tester.tap(find.text(period));
      await tester.pumpAndSettle();
      // The summary sits above the overview; All time has nothing before it.
      expect(find.text(period == 'All' ? 'At a glance' : 'Compared with before'), findsOneWidget);
      expect(find.text('Avg Sleep'), findsNothing, reason: 'the stat cards repeated the summary');
      await tester.scrollUntilVisible(find.text(grid), 300, scrollable: scrollable);
      await tester.scrollUntilVisible(find.text(mood), 300, scrollable: scrollable);
      await tester.scrollUntilVisible(find.text(table), 300, scrollable: scrollable);
    }
  });
}
