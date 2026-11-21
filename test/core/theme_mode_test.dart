import 'package:daily_rhythm/core/theme/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => themeClock = DateTime.now);

  test('follows the system until a mode is picked, and remembers the pick', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.system);
    await container.read(appearanceProvider.notifier).set(Appearance.dark);
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect((await SharedPreferences.getInstance()).getString('theme_mode'), 'dark');

    SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
    final again = ProviderContainer();
    addTearDown(again.dispose);
    again.read(appearanceProvider);
    await Future<void>.delayed(Duration.zero);
    expect(again.read(themeModeProvider), ThemeMode.light);
  });

  test('Time is light from 7am and dark from 7pm', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'time'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appearanceProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appearanceProvider), Appearance.time);

    themeClock = () => DateTime(2026, 11, 21, 12);
    container.invalidate(themeModeProvider);
    expect(container.read(themeModeProvider), ThemeMode.light);
    themeClock = () => DateTime(2026, 11, 21, 6, 59);
    container.invalidate(themeModeProvider);
    expect(container.read(themeModeProvider), ThemeMode.dark);
    themeClock = () => DateTime(2026, 11, 21, 19);
    container.invalidate(themeModeProvider);
    expect(container.read(themeModeProvider), ThemeMode.dark);

    expect(Appearance.nextSwitch(DateTime(2026, 11, 21, 12)), DateTime(2026, 11, 21, 19));
    expect(Appearance.nextSwitch(DateTime(2026, 11, 21, 22)), DateTime(2026, 11, 22, 7));
    expect(Appearance.nextSwitch(DateTime(2026, 11, 21, 3)), DateTime(2026, 11, 21, 7));
  });
}
