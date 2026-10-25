import 'package:daily_rhythm/core/theme/app_theme.dart';
import 'package:daily_rhythm/features/metrics/presentation/screens/metrics_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    for (final label in ['7D', '30D', 'Month', 'Year', 'All']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(0), reason: '$label starts off-screen');
      expect(rect.right, lessThanOrEqualTo(screenWidth), reason: '$label runs off-screen');
    }

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    final selector = tester.widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>));
    expect(selector.selected, {3});
  });
}
