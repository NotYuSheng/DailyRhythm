import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/plant_ink.dart';

/// How plants are drawn, kept in preferences: the soft flat look, or ink
/// line and wash.
class PlantStyleNotifier extends Notifier<PlantStyle> {
  static const _key = 'plant_style';

  @override
  PlantStyle build() {
    _load();
    return PlantStyle.soft;
  }

  Future<void> _load() async {
    final saved = (await SharedPreferences.getInstance()).getString(_key);
    if (saved != null) state = PlantStyle.byName(saved);
  }

  Future<void> set(PlantStyle style) async {
    state = style;
    await (await SharedPreferences.getInstance()).setString(_key, style.name);
  }
}

final plantStyleProvider = NotifierProvider<PlantStyleNotifier, PlantStyle>(PlantStyleNotifier.new);
