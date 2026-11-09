import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../meals/data/providers/meal_providers.dart';
import '../domain/ai_settings.dart';
import 'ai_client.dart';
import 'ai_settings_repository.dart';
import 'web_search.dart';

final aiSettingsRepositoryProvider = Provider<AiSettingsRepository>((ref) => AiSettingsRepository());

/// The saved AI settings; save to update everywhere.
class AiSettingsNotifier extends AsyncNotifier<AiSettings> {
  @override
  Future<AiSettings> build() => ref.read(aiSettingsRepositoryProvider).load();

  Future<void> save(AiSettings settings) async {
    await ref.read(aiSettingsRepositoryProvider).save(settings);
    state = AsyncData(settings);
  }
}

final aiSettingsProvider = AsyncNotifierProvider<AiSettingsNotifier, AiSettings>(AiSettingsNotifier.new);

/// A client for the current settings, or null while AI is off or unset.
/// It can look calories up in the app's food databases, and on the web when
/// search is set up.
final aiClientProvider = Provider<AiClient?>((ref) {
  final settings = ref.watch(aiSettingsProvider).value;
  if (settings == null || !settings.ready) return null;
  return AiClient(settings, null, ref.watch(calorieLookupProvider), WebSearch.of(settings));
});
