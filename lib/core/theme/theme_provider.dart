import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the app picks light or dark.
enum Appearance {
  system('System'),
  light('Light'),
  dark('Dark'),

  /// Light by day, dark by night, whatever the phone is set to.
  time('Time');

  const Appearance(this.label);

  final String label;

  /// Light from 7am, dark from 7pm.
  static const lightFrom = 7, darkFrom = 19;

  static bool isDaytime(DateTime t) => t.hour >= lightFrom && t.hour < darkFrom;

  /// When daytime next starts or ends after [t].
  static DateTime nextSwitch(DateTime t) {
    final hour = isDaytime(t) ? darkFrom : lightFrom;
    final today = DateTime(t.year, t.month, t.day, hour);
    return today.isAfter(t) ? today : DateTime(t.year, t.month, t.day + 1, hour);
  }
}

/// The appearance the user picked, saved on the phone.
class AppearanceNotifier extends Notifier<Appearance> {
  static const String _key = 'theme_mode';

  /// Follows the phone's light or dark setting until the user picks one.
  @override
  Appearance build() {
    _load();
    return Appearance.system;
  }

  Future<void> _load() async {
    final saved = (await SharedPreferences.getInstance()).getString(_key);
    for (final a in Appearance.values) {
      if (a.name == saved) state = a;
    }
  }

  Future<void> set(Appearance appearance) async {
    state = appearance;
    await (await SharedPreferences.getInstance()).setString(_key, appearance.name);
  }
}

final appearanceProvider = NotifierProvider<AppearanceNotifier, Appearance>(AppearanceNotifier.new);

/// The clock the Time appearance reads; tests set it.
DateTime Function() themeClock = DateTime.now;

/// The theme mode the app uses now. With Time it changes by itself at 7am
/// and 7pm.
final themeModeProvider = Provider<ThemeMode>((ref) {
  switch (ref.watch(appearanceProvider)) {
    case Appearance.system:
      return ThemeMode.system;
    case Appearance.light:
      return ThemeMode.light;
    case Appearance.dark:
      return ThemeMode.dark;
    case Appearance.time:
      final now = themeClock();
      // A second past the hour, so the check lands after the switch.
      final timer = Timer(Appearance.nextSwitch(now).difference(now) + const Duration(seconds: 1), ref.invalidateSelf);
      ref.onDispose(timer.cancel);
      return Appearance.isDaytime(now) ? ThemeMode.light : ThemeMode.dark;
  }
});
