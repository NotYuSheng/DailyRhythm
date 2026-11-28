import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/services/database/database_service.dart';
import '../tidy/presentation/tidy_screen.dart';
import 'release_notes.dart';

/// The release notes the user hasn't seen, after an update, or all of them
/// from Settings, with an offer to update older entries with the AI.
class WhatsNewScreen extends ConsumerWidget {
  const WhatsNewScreen({super.key, this.notes = releaseNotes});

  final List<ReleaseNote> notes;

  static const seenKey = 'whats_new_seen';

  /// Notes newer than the last ones seen. A first install has nothing to
  /// catch up on, so it starts as seen; an update from before this screen
  /// sees the lot.
  static Future<List<ReleaseNote>> unseen(DatabaseService database) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getString(seenKey);
    if (seen == null) {
      final db = await database.database;
      final logged = (await db.rawQuery('SELECT EXISTS (SELECT 1 FROM meal_entries) OR EXISTS (SELECT 1 FROM sleep_entries) AS any')).first['any'];
      if (logged == 0) {
        await markSeen();
        return const [];
      }
      return releaseNotes;
    }
    final at = releaseNotes.indexWhere((n) => n.version == seen);
    return at < 0 ? releaseNotes : releaseNotes.sublist(0, at);
  }

  static Future<void> markSeen() async {
    if (releaseNotes.isEmpty) return;
    await (await SharedPreferences.getInstance()).setString(seenKey, releaseNotes.first.version);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final update = [for (final n in notes) ?n.dataUpdate];
    return PopScope(
      onPopInvokedWithResult: (_, _) => markSeen(),
      child: Scaffold(
        appBar: AppBar(title: const Text('What’s new')),
        body: ListView(
          padding: const EdgeInsets.all(AppTheme.spacePulse3),
          children: [
            for (final n in notes)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacePulse3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Version ${n.version}', style: theme.textTheme.titleLarge),
                      const SizedBox(height: AppTheme.spacePulse2),
                      for (final item in n.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [const Text('•  '), Expanded(child: Text(item))],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (update.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacePulse3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Update your older entries', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppTheme.spacePulse2),
                      for (final u in update) Text(u),
                      const SizedBox(height: AppTheme.spacePulse3),
                      Wrap(
                        spacing: AppTheme.spacePulse2,
                        runSpacing: AppTheme.spacePulse1,
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.auto_awesome_outlined),
                            label: const Text('Update my data with AI'),
                            onPressed: () async {
                              await markSeen();
                              if (!context.mounted) return;
                              await Navigator.pushReplacement(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => TidyScreen(start: DateTime(2000), end: DateTime.now(), askAi: true, title: 'Update my data'),
                                ),
                              );
                            },
                          ),
                          TextButton(
                            onPressed: () async {
                              await markSeen();
                              if (context.mounted) Navigator.pop(context);
                            },
                            child: const Text('Later'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacePulse1),
                      Text('You can do this any time from Settings > What’s new, or Tidy up entries.', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
