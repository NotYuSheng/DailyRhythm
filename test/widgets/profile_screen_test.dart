import 'package:daily_rhythm/core/theme/app_theme.dart';
import 'package:daily_rhythm/features/profile/data/profile_repository.dart';
import 'package:daily_rhythm/features/profile/domain/profile.dart';
import 'package:daily_rhythm/features/profile/presentation/profile_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the profile shows its ranges as you type, and saves', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProfileScreen())),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Sleep: 7–9 hours a night'), findsOneWidget);
    expect(find.text('Calories: add your year of birth, height and weight'), findsOneWidget);

    final year = DateTime.now().year - 15;
    await tester.enterText(find.widgetWithText(TextField, 'Year of birth'), '$year');
    await tester.enterText(find.widgetWithText(TextField, 'Height'), '170');
    await tester.enterText(find.widgetWithText(TextField, 'Weight'), '60');
    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();
    expect(find.text('Sleep: 8–10 hours a night'), findsOneWidget, reason: 'a teenager’s range');
    expect(find.textContaining('Calories: about'), findsOneWidget);

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = await ProfileRepository().load();
    expect((saved.birthYear, saved.heightCm, saved.weightKg, saved.sex), (year, 170.0, 60.0, Sex.female));
  });
}
