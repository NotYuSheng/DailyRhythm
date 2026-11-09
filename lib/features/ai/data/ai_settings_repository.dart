import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ai_settings.dart';

/// Saves the AI settings. The API keys (the AI's and web search's) are kept apart, each in a file of its own
/// in the app's private storage: never exported, never in Drive backups,
/// and left out of Android's cloud backup (res/xml/backup_rules.xml).
class AiSettingsRepository {
  AiSettingsRepository({Future<Directory> Function()? keyDirectory}) : _keyDirectory = keyDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _keyDirectory;

  static const _enabled = 'ai_enabled';
  static const _provider = 'ai_provider';
  static const _baseUrl = 'ai_base_url';
  static const _model = 'ai_model';
  static const _search = 'ai_search';
  static const _searchUrl = 'ai_search_url';
  static const keyFile = 'ai_key';
  static const searchKeyFile = 'ai_search_key';

  Future<File> _file(String name) async => File('${(await _keyDirectory()).path}/$name');

  Future<String> _read(String name) async {
    final f = await _file(name);
    return await f.exists() ? (await f.readAsString()).trim() : '';
  }

  Future<void> _write(String name, String value) async {
    final f = await _file(name);
    if (value.trim().isEmpty) {
      if (await f.exists()) await f.delete();
    } else {
      await f.parent.create(recursive: true);
      await f.writeAsString(value.trim(), flush: true);
    }
  }

  Future<AiSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AiSettings(
      enabled: prefs.getBool(_enabled) ?? false,
      provider: AiProvider.byName(prefs.getString(_provider)),
      baseUrl: prefs.getString(_baseUrl) ?? '',
      model: prefs.getString(_model) ?? '',
      apiKey: await _read(keyFile),
      search: SearchProvider.byName(prefs.getString(_search)),
      searchUrl: prefs.getString(_searchUrl) ?? '',
      searchKey: await _read(searchKeyFile),
    );
  }

  Future<void> save(AiSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabled, s.enabled);
    await prefs.setString(_provider, s.provider.name);
    await prefs.setString(_baseUrl, s.baseUrl.trim());
    await prefs.setString(_model, s.model.trim());
    await prefs.setString(_search, s.search.name);
    await prefs.setString(_searchUrl, s.searchUrl.trim());
    await _write(keyFile, s.apiKey);
    await _write(searchKeyFile, s.searchKey);
  }
}
