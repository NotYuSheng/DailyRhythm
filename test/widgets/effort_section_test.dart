import 'dart:io';
import 'dart:ui' as ui;

import 'package:daily_rhythm/features/metrics/data/models/metric_data.dart';
import 'package:daily_rhythm/features/metrics/data/services/effort_report.dart';
import 'package:daily_rhythm/features/metrics/presentation/widgets/effort_section.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final range = DateRange.month(DateTime(2026, 11, 9), today: DateTime(2026, 11, 9));
  final key = GlobalKey();

  Future<void> pump(WidgetTester tester, EffortReport report) async {
    tester.view.physicalSize = const Size(1080, 1800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [effortReportProvider.overrideWith((ref, r) async => report)],
      child: MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: RepaintBoundary(key: key, child: EffortSection(range: range))))),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows exercise days by effort, the usual level, the hardest weekday and the change', (tester) async {
    await pump(tester, const EffortReport(byLevel: [2, 5, 4, 3, 1], days: 30, byWeekday: [2.0, 3.2, null, 2.5, 1.8, 4.1, 3.0], perWeek: 3.5, previousPerWeek: 2.6));
    expect(find.text('15'), findsOneWidget);
    expect(find.text('Moderate'), findsOneWidget);
    expect(find.text('4'), findsOneWidget, reason: 'Hard and Very hard days');
    expect(find.text('Hardest on Saturdays'), findsOneWidget);
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
    await pump(tester, const EffortReport(byLevel: [0, 0, 0, 0, 0], days: 9, byWeekday: [null, null, null, null, null, null, null]));
    expect(find.text('Log exercise to see how hard your days were.'), findsOneWidget);
  });
}
