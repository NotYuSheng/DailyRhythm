import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ai_settings.dart';

/// Saves the AI settings. The API key is kept apart, in a file of its own
/// in the app's private storage: never exported, never in Drive backups,
/// and left out of Android's cloud backup (res/xml/backup_rules.xml).
class AiSettingsRepository {
  AiSettingsRepository({Future<Directory> Function()? keyDirectory}) : _keyDirectory = keyDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _keyDirectory;

  static const _enabled = 'ai_enabled';
  static const _provider = 'ai_provider';
  static const _baseUrl = 'ai_base_url';
  static const _model = 'ai_model';
  static const keyFile = 'ai_key';

  Future<File> _key() async => File('${(await _keyDirectory()).path}/$keyFile');

  Future<AiSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _key();
    return AiSettings(
      enabled: prefs.getBool(_enabled) ?? false,
      provider: AiProvider.byName(prefs.getString(_provider)),
      baseUrl: prefs.getString(_baseUrl) ?? '',
      model: prefs.getString(_model) ?? '',
      apiKey: await key.exists() ? (await key.readAsString()).trim() : '',
    );
  }

  Future<void> save(AiSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabled, s.enabled);
    await prefs.setString(_provider, s.provider.name);
    await prefs.setString(_baseUrl, s.baseUrl.trim());
    await prefs.setString(_model, s.model.trim());
    final key = await _key();
    if (s.apiKey.trim().isEmpty) {
      if (await key.exists()) await key.delete();
    } else {
      await key.parent.create(recursive: true);
      await key.writeAsString(s.apiKey.trim(), flush: true);
    }
  }
}
