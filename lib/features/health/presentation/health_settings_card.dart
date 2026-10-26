import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../shared/services/database/database_provider.dart';
import '../../garden/data/garden_providers.dart';
import '../../metrics/data/providers/metrics_providers.dart';
import '../data/health_sync_service.dart';

/// Refreshes what shows health data after a sync or import.
void invalidateHealth(WidgetRef ref) {
  ref.invalidate(gardenDayProvider);
  ref.invalidate(gardenMonthProvider);
  invalidateMetrics(ref);
}

/// Settings for health data: sync with the phone's health store (asked
/// for only when turned on) and importing a Garmin export.
class HealthSettingsCard extends ConsumerStatefulWidget {
  const HealthSettingsCard({super.key});

  @override
  ConsumerState<HealthSettingsCard> createState() => _HealthSettingsCardState();
}

class _HealthSettingsCardState extends ConsumerState<HealthSettingsCard> {
  bool _enabled = false;
  DateTime? _lastSync;
  bool _busy = false;

  static String get _store => defaultTargetPlatform == TargetPlatform.iOS
      ? 'Apple Health'
      : 'Health Connect';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await HealthSyncService.isEnabled();
    final last = await HealthSyncService.lastSync();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _lastSync = last;
      });
    }
  }

  HealthSyncService get _service =>
      HealthSyncService(ref.read(databaseProvider));

  Future<void> _work(Future<String> Function() task) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      message = await task();
    } catch (e) {
      message = 'Something went wrong: $e';
    }
    if (!mounted) return;
    invalidateHealth(ref);
    await _load();
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle(bool on) => _work(() async {
    final (enabled, reason) = await _service.setEnabled(on);
    if (!on) return 'Sync with $_store is off';
    if (!enabled) return reason ?? 'Couldn’t turn on sync';
    final days = await _service.sync();
    return 'Synced $days ${days == 1 ? 'day' : 'days'} from $_store';
  });

  Future<void> _syncNow() => _work(() async {
    final days = await _service.sync();
    return 'Synced $days ${days == 1 ? 'day' : 'days'} from $_store';
  });

  Future<void> _importGarmin() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Read from disk, not into memory: exports can be gigabytes.
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose a Garmin export',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = picked?.files.singleOrNull?.path;
    if (path == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    await _work(() async {
      final (days, workouts) = await _service.importGarmin(path);
      return 'Imported $days ${days == 1 ? 'day' : 'days'} and $workouts ${workouts == 1 ? 'workout' : 'workouts'}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final last = _lastSync == null
        ? 'Not synced yet'
        : 'Last synced ${DateFormat('d MMM, HH:mm').format(_lastSync!)}';
    return Card(
      child: Column(
        children: [
          if (HealthSyncService.isSupported) ...[
            SwitchListTile(
              secondary: const Icon(Icons.favorite_outline),
              title: Text('Sync with $_store'),
              subtitle: Text(
                _enabled ? last : 'Steps, sleep, resting heart rate and workouts. Read only.',
              ),
              value: _enabled,
              onChanged: _busy ? null : _toggle,
            ),
            if (_enabled) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Sync now'),
                trailing: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _busy ? null : _syncNow,
              ),
            ],
            const Divider(height: 1),
          ],
          ListTile(
            leading: const Icon(Icons.watch_outlined),
            title: const Text('Import Garmin export'),
            subtitle: const Text(
              'The zip from Garmin Connect → Export Your Data',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _busy ? null : _importGarmin,
          ),
        ],
      ),
    );
  }
}
