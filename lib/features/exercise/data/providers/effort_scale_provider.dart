import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/effort.dart';

/// The effort scale chosen in Settings, kept in preferences. Anything that
/// shows effort levels watches this, so a change redraws it.
class EffortScaleNotifier extends Notifier<EffortScale> {
  static const _key = 'effort_scale';

  /// Reads the saved scale into [Effort.scale]; called before the app runs.
  static Future<void> load() async {
    Effort.scale = EffortScale.byName((await SharedPreferences.getInstance()).getString(_key));
  }

  @override
  EffortScale build() => Effort.scale;

  Future<void> set(EffortScale scale) async {
    Effort.scale = scale;
    state = scale;
    await (await SharedPreferences.getInstance()).setString(_key, scale.name);
  }
}

final effortScaleProvider = NotifierProvider<EffortScaleNotifier, EffortScale>(EffortScaleNotifier.new);
