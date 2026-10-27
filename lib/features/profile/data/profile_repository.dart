import 'package:shared_preferences/shared_preferences.dart';

import '../domain/profile.dart';

/// The profile, kept in this device's preferences only.
class ProfileRepository {
  static const _birthYear = 'profile_birth_year';
  static const _height = 'profile_height_cm';
  static const _weight = 'profile_weight_kg';
  static const _sex = 'profile_sex';

  Future<Profile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return Profile(
      birthYear: prefs.getInt(_birthYear),
      heightCm: prefs.getDouble(_height),
      weightKg: prefs.getDouble(_weight),
      sex: Sex.byName(prefs.getString(_sex)),
    );
  }

  Future<void> save(Profile p) async {
    final prefs = await SharedPreferences.getInstance();
    Future<void> put<T>(String key, T? value, Future<bool> Function(String, T) set) async =>
        value == null ? await prefs.remove(key) : await set(key, value);
    await put(_birthYear, p.birthYear, prefs.setInt);
    await put(_height, p.heightCm, prefs.setDouble);
    await put(_weight, p.weightKg, prefs.setDouble);
    await put(_sex, p.sex?.name, prefs.setString);
  }
}
