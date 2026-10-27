import 'package:daily_rhythm/core/theme/app_theme.dart';
import 'package:daily_rhythm/features/metrics/presentation/screens/metrics_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_rhythm/shared/models/mood_entry.dart';
import 'package:daily_rhythm/features/garden/presentation/screens/garden_today_screen.dart';
import 'package:intl/intl.dart';
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

  testWidgets('a grid square shows its value on tap and opens the day on double-tap', (tester) async {
    final db = await openTestDatabase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await db.upsertMoodEntry(MoodEntry(date: today, timestamp: today, moodLevel: 4, emoji: ''));
    await tester.pumpWidget(ProviderScope(child: MaterialApp(theme: AppTheme.lightTheme, home: const MetricsScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.widgetWithText(ChoiceChip, 'Mood'), 300, scrollable: scrollable);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mood'));
    await tester.pumpAndSettle();

    final label = DateFormat('EEE d MMM y').format(today);
    final square = find.byWidgetPredicate((w) => w is Tooltip && (w.message ?? '').startsWith(label));
    await tester.ensureVisible(square);
    await tester.pumpAndSettle();
    await tester.tap(square);
    await tester.pump(const Duration(milliseconds: 400)); // past the double-tap wait
    await tester.pumpAndSettle();
    expect(find.text('$label\nMood: Good\nDouble-tap to open the day'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.tap(square);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(square);
    // Today's plant sways for ever, so pump the page transition through.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GardenTodayScreen), findsOneWidget);
  });
}
