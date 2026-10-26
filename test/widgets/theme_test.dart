import 'package:daily_rhythm/core/theme/app_theme.dart';
import 'package:daily_rhythm/features/tags/presentation/screens/tags_screen.dart';
import 'package:daily_rhythm/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_database.dart';

/// WCAG relative-luminance contrast ratio between two opaque colors.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUp(() async => openTestDatabase());
  tearDown(closeTestDatabase);

  for (final mode in ['light', 'dark']) {
    group('$mode theme', () {
      final theme = mode == 'light' ? AppTheme.lightTheme : AppTheme.darkTheme;

      test('text roles are readable on surfaces (WCAG AA, 4.5:1)', () {
        final c = theme.colorScheme;
        expect(_contrast(c.onSurface, c.surface), greaterThan(4.5));
        expect(_contrast(c.onSurfaceVariant, c.surface), greaterThan(4.5));
        expect(_contrast(c.onPrimary, c.primary), greaterThan(4.5));
        expect(_contrast(c.onSurface, theme.scaffoldBackgroundColor), greaterThan(4.5));
      });

      // Pumps every tab on a 360dp phone; any overflow or exception fails.
      // The test font draws every glyph as a full em square, roughly twice
      // as wide as Roboto, so this also approximates Android's 200% font
      // size setting rather than the default text size.
      testWidgets('every tab renders on a 360dp phone', (tester) async {
        SharedPreferences.setMockInitialValues({'theme_mode': mode});
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        // The plant sways unless reduced motion is on; tests can't settle on a loop.
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

        await tester.pumpWidget(const ProviderScope(child: DailyRhythmApp()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Today tab threw while rendering');
        expect(find.text('Today\u2019s plant'), findsOneWidget);

        for (final tab in ['Garden', 'Metrics', 'Settings', 'Today']) {
          await tester.tap(find.text(tab).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$tab tab threw while rendering');
        }
        expect(Theme.of(tester.element(find.text('Today\u2019s plant'))).brightness,
            mode == 'light' ? Brightness.light : Brightness.dark);

        // Icons must stand out against the page in both modes; the old
        // hardcoded black icons disappeared in dark mode.
        final background = theme.scaffoldBackgroundColor;
        for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
          final color = icon.color ?? IconTheme.of(tester.element(find.byWidget(icon))).color!;
          if (color.a < 0.5) continue; // disabled/decorative
          expect(_contrast(color, background), greaterThan(3), reason: '${icon.icon} is hard to see');
        }
      });

      testWidgets('tags screen renders on a 360dp phone', (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(ProviderScope(
          child: MaterialApp(theme: theme, home: const TagsScreen()),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Health'), findsWidgets);
      });
    });
  }
}
