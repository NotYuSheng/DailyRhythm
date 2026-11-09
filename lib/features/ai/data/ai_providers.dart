import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ai_settings.dart';
import 'ai_client.dart';
import 'ai_settings_repository.dart';

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
final aiClientProvider = Provider<AiClient?>((ref) {
  final settings = ref.watch(aiSettingsProvider).value;
  return settings != null && settings.ready ? AiClient(settings) : null;
});
