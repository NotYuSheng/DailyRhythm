import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../services/theme_provider.dart';

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
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('Backup & Sync'),
                  subtitle: const Text('Google Drive backup'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: Implement backup/sync
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Export Data'),
                  subtitle: const Text('Export to Excel'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: Implement export
                  },
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
            child: ListTile(
              leading: const Icon(Icons.info_outlined),
              title: const Text('About'),
              subtitle: const Text('Version 1.0.0'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showAboutDialog(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'LifeRhythm',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 LifeRhythm\nMonochrome rhythm-inspired daily tracking',
      children: [
        const SizedBox(height: AppTheme.spacePulse3),
        Text(
          'Track your daily rhythms:\n• Sleep patterns\n• Meal habits\n• Custom tags\n• Data insights',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
