import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../shared/services/export/export_service.dart';
import '../../../../shared/providers/common_providers.dart';
import '../../../sleep/data/providers/sleep_providers.dart';
import '../../../meals/data/providers/meal_providers.dart';
import '../../../exercise/data/providers/exercise_providers.dart';
import '../../../tags/data/providers/tag_providers.dart';
import '../../../tags/presentation/screens/tags_screen.dart';
import '../../../health/presentation/health_settings_card.dart';
import '../../../garden/data/garden_providers.dart';
import '../../../spending/data/spending_providers.dart';
import '../../../metrics/data/providers/metrics_providers.dart';
import '../../../profile/presentation/profile_screen.dart';
import 'backup_settings_screen.dart';
import 'debug_database_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.label_outline),
              title: const Text('Tags'),
              subtitle: const Text('Activities, symptoms and food sources'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const TagsScreen())),
            ),
          ),
          const SizedBox(height: AppTheme.spacePulse3),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Your profile'),
              subtitle: const Text('Age, height and weight for typical ranges'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProfileScreen())),
            ),
          ),
          const SizedBox(height: AppTheme.spacePulse3),
          const HealthSettingsCard(),
          const SizedBox(height: AppTheme.spacePulse3),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('Backup & Sync'),
                  subtitle: const Text('Google Drive backup'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BackupSettingsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Export Data'),
                  subtitle: const Text('Save all data as a zip of CSV files'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _handleExportData(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.upload_outlined),
                  title: const Text('Import Data'),
                  subtitle: const Text('Load an export zip or CSV files'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _handleImportData(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacePulse3),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
                  title: const Text('Dark Mode'),
                  subtitle: Text(isDarkMode ? 'Dark theme enabled' : 'Light theme enabled'),
                  value: isDarkMode,
                  onChanged: (bool value) {
                    ref.read(themeModeProvider.notifier).toggleTheme();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  subtitle: const Text('Reminders and alerts'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: Implement notifications
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacePulse3),
          Card(
            child: Column(
              children: [
                // Raw database viewer is for development builds only
                if (kDebugMode) ...[
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: const Text('Debug Database'),
                    subtitle: const Text('View database contents'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DebugDatabaseScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                ],
                ListTile(
                  leading: const Icon(Icons.info_outlined),
                  title: const Text('About'),
                  subtitle: const Text('Version 1.0.0'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _showAboutDialog(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'DailyRhythm',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 DailyRhythm\nRhythm-inspired daily tracking',
      children: [
        const SizedBox(height: AppTheme.spacePulse3),
        Text(
          'Track your daily rhythms:\n• Sleep patterns\n• Meal habits\n• Custom tags\n• Data insights',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Future<void> _handleExportData(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text(
          'This will export all your data as a zip of CSV files. You choose where to save it next. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Export'),
          ),
        ],
      ),
    );

    // If user cancelled, return early
    if (confirmed != true) return;

    // Show loading dialog
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spacePulse4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: AppTheme.spacePulse3),
                  Text('Exporting your data...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final exportService = ExportService.instance;

      // Export all data - this opens the system save dialog
      final result = await exportService.exportAllData();

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show success message with location
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result == null
                  ? 'Export cancelled'
                  : 'Exported ${result.totalEntries} entries in ${result.fileCount} files',
            ),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleImportData(BuildContext context, WidgetRef ref) async {
    // Rows applied so far and the total; null until the file is read.
    final progress = ValueNotifier<(int, int)?>(null);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacePulse4),
            child: SizedBox(
              width: 240,
              child: ValueListenableBuilder(
                valueListenable: progress,
                builder: (context, value, _) {
                  final (done, total) = value ?? (0, 0);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(value: total == 0 ? null : done / total),
                      const SizedBox(height: AppTheme.spacePulse3),
                      Text(total == 0 ? 'Importing your data...' : 'Importing $done of $total entries'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final exportService = ExportService.instance;

      // Opens a file picker, then imports in one transaction.
      final result = await exportService.importData(
        onProgress: (done, total) => progress.value = (done, total),
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Refresh every screen that shows imported data
      if (result != null) {
        for (final provider in [
          sleepEntriesProvider,
          mealEntriesProvider,
          moodEntryProvider,
          exerciseEntriesProvider,
          taskEntriesProvider,
          activityEntriesProvider,
          tagsByCategoryProvider,
          gardenDayProvider,
          gardenMonthProvider,
          monthRecapProvider,
          gardenYearProvider,
          periodOverviewProvider,
          checkinProvider,
          momentsProvider,
          spendingProvider,
          todaySleepEntriesProvider,
          todayMealEntriesProvider,
          todayMoodEntryProvider,
          allTagsProvider,
          allTagCategoriesProvider,
        ]) {
          ref.invalidate(provider);
        }
        invalidateMetrics(ref);
      }

      final String message;
      if (result == null) {
        message = 'Import cancelled';
      } else if (!result.foundFiles) {
        message = 'No DailyRhythm export files found in that folder';
      } else {
        message = 'Imported ${result.imported} entries'
            '${result.duplicates > 0 ? ', skipped ${result.duplicates} already present' : ''}'
            '${result.invalid > 0 ? ', ${result.invalid} unreadable rows' : ''}';
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
