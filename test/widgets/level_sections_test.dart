import 'dart:io';
import 'dart:ui' as ui;

import 'package:daily_rhythm/features/metrics/data/models/metric_data.dart';
import 'package:daily_rhythm/features/metrics/data/services/level_report.dart';
import 'package:daily_rhythm/features/metrics/presentation/widgets/level_sections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final range = DateRange.month(DateTime(2026, 11, 9), today: DateTime(2026, 11, 9));
  final key = GlobalKey();

  Future<void> pump(WidgetTester tester, LevelReport report, {bool calories = false, bool days = false}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 1800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        effortReportProvider.overrideWith((ref, r) async => report),
        calorieReportProvider.overrideWith((ref, r) async => report),
        healthReportProvider.overrideWith((ref, r) async => report),
        ratingReportProvider.overrideWith((ref, r) async => report),
      ],
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: RepaintBoundary(key: key, child: days ? HowDaysWentSection(range: range) : calories ? FoodSection(range: range) : EffortSection(range: range))))),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows exercise days by effort, the usual level, the hardest weekday and the change', (tester) async {
    await pump(tester, const LevelReport(byLevel: [2, 5, 4, 3, 1], days: 30, byWeekday: [[0, 1, 0, 0, 0], [0, 2, 1, 0, 0], [0, 0, 0, 0, 0], [1, 1, 1, 0, 0], [1, 0, 0, 0, 0], [0, 1, 1, 3, 1], [0, 0, 1, 0, 0]], perWeek: 3.5, previousPerWeek: 2.6));
    expect(find.text('15'), findsOneWidget);
    expect(find.text('Moderate'), findsOneWidget);
    expect(find.text('4'), findsOneWidget, reason: 'Hard and Very hard days');
    expect(find.text('Most exercise days on Saturdays'), findsOneWidget);
    expect(find.text('6'), findsOneWidget, reason: 'Saturday’s stacked bar is labelled with its days');
    expect(find.text('3.5 exercise days a week, up from 2.6 last month'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (Platform.environment['EFFORT_PREVIEW'] case final out?) {
      await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 2);
        File(out).writeAsBytesSync((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
      });
    }
  });

  testWidgets('without exercise it says how to fill it', (tester) async {
    await pump(tester, LevelReport(byLevel: const [0, 0, 0, 0, 0], days: 9, byWeekday: [for (var i = 0; i < 7; i++) const [0, 0, 0, 0, 0]]));
    expect(find.text('Log exercise to see how hard your days were.'), findsOneWidget);
  });

  testWidgets('calories: average a day, days logged and the change', (tester) async {
    await pump(
      tester,
      const LevelReport(byLevel: [1, 3, 6, 2, 0], days: 30, byWeekday: [[0, 1, 0, 0, 0], [0, 2, 1, 0, 0], [0, 0, 0, 0, 0], [1, 1, 1, 0, 0], [1, 0, 0, 0, 0], [0, 1, 1, 3, 1], [0, 0, 1, 0, 0]], average: 2050, previousAverage: 1890, perWeek: 2.8, previousPerWeek: 3),
      calories: true,
    );
    expect(find.text('≈2,050'), findsOneWidget);
    expect(find.text('of 30 days'), findsOneWidget);
    expect(find.text('≈2,050 a day, up from ≈1,890 last month'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('food switches to how healthy the meals were', (tester) async {
    await pump(
      tester,
      const LevelReport(byLevel: [1, 3, 6, 2, 0], days: 30, byWeekday: [[0, 1, 0, 0, 0], [0, 2, 1, 0, 0], [0, 0, 0, 0, 0], [1, 1, 1, 0, 0], [1, 0, 0, 0, 0], [0, 1, 1, 3, 1], [0, 0, 1, 0, 0]], average: 3.2, previousAverage: 2.9, perWeek: 2.8, previousPerWeek: 3),
      calories: true,
    );
    await tester.tap(find.text('Health'));
    await tester.pumpAndSettle();
    expect(find.text('3.2/5'), findsOneWidget);
    expect(find.text('Averaged 3.2/5, up from 2.9 last month'), findsOneWidget);
  });

  testWidgets('how days went shows mood, and energy against a usual day', (tester) async {
    await pump(
      tester,
      const LevelReport(byLevel: [0, 1, 3, 6, 2], days: 30, byWeekday: [[0, 1, 0, 0, 0], [0, 2, 1, 0, 0], [0, 0, 0, 0, 0], [1, 1, 1, 0, 0], [1, 0, 0, 0, 0], [0, 1, 1, 3, 1], [0, 0, 1, 0, 0]], average: 3.7, previousAverage: 3.3, perWeek: 2.8, previousPerWeek: 3),
      days: true,
    );
    expect(find.text('Good'), findsWidgets);
    expect(find.text('8'), findsOneWidget, reason: 'good days');
    expect(find.text('Mood averaged 3.7, higher than 3.3 last month'), findsOneWidget);
    await tester.tap(find.text('Energy'));
    await tester.pumpAndSettle();
    expect(find.text('Energy compared with a usual day'), findsOneWidget);
    expect(find.text('Energy averaged +3.7, higher than +3.3 last month'), findsOneWidget);
  });
}
