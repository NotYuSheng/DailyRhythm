import 'package:daily_rhythm/core/theme/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('follows the system until a mode is picked, and remembers the pick', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.system);
    await container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
    expect((await SharedPreferences.getInstance()).getString('theme_mode'), 'dark');

    SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
    final again = ProviderContainer();
    addTearDown(again.dispose);
    again.read(themeModeProvider);
    await Future<void>.delayed(Duration.zero);
    expect(again.read(themeModeProvider), ThemeMode.light);
  });
}
