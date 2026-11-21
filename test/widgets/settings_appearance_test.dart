import 'package:daily_rhythm/core/theme/app_theme.dart';
import 'package:daily_rhythm/core/theme/theme_provider.dart';
import 'package:daily_rhythm/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_database.dart';

void main() {
  testWidgets('Appearance offers Time, and its choices fit a 360dp phone with large text', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await openTestDatabase();
    addTearDown(closeTestDatabase);
    tester.view.physicalSize = const Size(1080, 2400); // 360×800 at 3×
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery.withClampedTextScaling(minScaleFactor: 1.3, maxScaleFactor: 1.3, child: const SettingsScreen()),
      ),
    ));
    await tester.pumpAndSettle();
    final time = find.descendant(of: find.byType(ChoiceChip), matching: find.text('Time'));
    await tester.scrollUntilVisible(time, 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(time);
    await tester.pumpAndSettle();
    await tester.tap(time, warnIfMissed: true);
    await tester.pumpAndSettle();
    for (final a in Appearance.values) {
      final label = find.descendant(of: find.byType(ChoiceChip), matching: find.text(a.label));
      expect(tester.getSize(label).height, lessThan(30), reason: '${a.label} stays on one line');
    }
    expect(find.text('Light from 7am, dark from 7pm'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('theme_mode'), Appearance.time.name);
  });
}
