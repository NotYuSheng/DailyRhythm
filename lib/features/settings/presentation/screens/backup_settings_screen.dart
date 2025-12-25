import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/backup/google_drive_service.dart';
import '../../../../shared/services/backup/backup_service.dart';
import '../../../../core/theme/app_theme.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  final GoogleDriveService _driveService = GoogleDriveService.instance;
  final BackupService _backupService = BackupService.instance;

  bool _isLoading = false;
  bool _isSignedIn = false;
  String? _userEmail;
  BackupStats? _stats;
  List<BackupFile> _backupFiles = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);

    await _driveService.initialize();
    _isSignedIn = _driveService.isSignedIn;
    _userEmail = _driveService.currentUser?.email;

    if (_isSignedIn) {
      await _loadStats();
      await _loadBackups();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadStats() async {
    final stats = await _backupService.getBackupStats();
    setState(() => _stats = stats);
  }

  Future<void> _loadBackups() async {
    try {
      final backups = await _driveService.listBackups();
      setState(() => _backupFiles = backups);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);

    try {
      final account = await _driveService.signIn();

      if (account != null) {
        setState(() {
          _isSignedIn = true;
          _userEmail = account.email;
        });

        await _loadStats();
        await _loadBackups();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Signed in as ${account.email}')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sign in failed - Check OAuth configuration in Google Cloud Console'),
              duration: Duration(seconds: 7),
            ),
          );
        }
      }
    } on UnsupportedError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Platform not supported'),
            backgroundColor: AppTheme.rhythmMediumGray,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in error: $e'),
            backgroundColor: AppTheme.rhythmMediumGray,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);

    await _driveService.signOut();

    setState(() {
      _isSignedIn = false;
      _userEmail = null;
      _stats = null;
      _backupFiles = [];
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out successfully')),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _performBackup() async {
    setState(() => _isLoading = true);

    final result = await _backupService.backupToGoogleDrive();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }

    if (result.success) {
      await _loadStats();
      await _loadBackups();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _performRestore() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from Backup'),
        content: const Text(
          'This will replace all current data with the latest backup. '
          'Your current data will be backed up first.\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.rhythmMediumGray,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    final result = await _backupService.restoreFromGoogleDrive();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _toggleAutoBackup(bool enabled) async {
    await _backupService.setAutoBackupEnabled(enabled);
    await _loadStats();
  }

  Future<void> _setBackupFrequency() async {
    final frequency = await _backupService.getAutoBackupFrequency();

    if (!mounted) return;

    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Backup Frequency'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 1),
            child: Row(
              children: [
                Icon(frequency == 1 ? Icons.check_circle : Icons.circle_outlined),
                const SizedBox(width: 16),
                const Text('Daily'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 3),
            child: Row(
              children: [
                Icon(frequency == 3 ? Icons.check_circle : Icons.circle_outlined),
                const SizedBox(width: 16),
                const Text('Every 3 days'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 7),
            child: Row(
              children: [
                Icon(frequency == 7 ? Icons.check_circle : Icons.circle_outlined),
                const SizedBox(width: 16),
                const Text('Weekly'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 14),
            child: Row(
              children: [
                Icon(frequency == 14 ? Icons.check_circle : Icons.circle_outlined),
                const SizedBox(width: 16),
                const Text('Every 2 weeks'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 30),
            child: Row(
              children: [
                Icon(frequency == 30 ? Icons.check_circle : Icons.circle_outlined),
                const SizedBox(width: 16),
                const Text('Monthly'),
              ],
            ),
          ),
        ],
      ),
    );

    if (selected != null) {
      await _backupService.setAutoBackupFrequency(selected);
      await _loadStats();
    }
  }

  Future<void> _deleteBackup(BackupFile backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Text('Delete backup from ${DateFormat.yMMMd().add_jm().format(backup.createdTime)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    final success = await _driveService.deleteBackup(backup.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Backup deleted' : 'Failed to delete backup'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }

    if (success) {
      await _loadBackups();
    }

    setState(() => _isLoading = false);
  }

  bool _isPlatformSupported() {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
           defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platformSupported = _isPlatformSupported();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Sync'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Platform warning banner
                if (!platformSupported)
                  Card(
                    color: platformSupported
                        ? null
                        : (theme.brightness == Brightness.dark
                            ? AppTheme.rhythmAccent1
                            : const Color(0x4DB0B0B0)), // 30% opacity rhythmLightGray
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: theme.brightness == Brightness.dark
                                ? AppTheme.rhythmLightGray
                                : AppTheme.rhythmMediumGray,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Platform Not Supported',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Google Drive backup is currently only supported on Android, iOS, and Web. '
                                  'Please run the app on a supported platform to use this feature.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!platformSupported) const SizedBox(height: 16),

                // Google Account Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Google Drive',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isSignedIn) ...[
                          ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text(_userEmail ?? 'Unknown'),
                            subtitle: const Text('Connected'),
                            trailing: TextButton(
                              onPressed: _signOut,
                              child: const Text('Sign Out'),
                            ),
                          ),
                        ] else ...[
                          const Text('Sign in to enable Google Drive backups'),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _signIn,
                            icon: const Icon(Icons.login),
                            label: const Text('Sign in with Google'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                if (_isSignedIn) ...[
                  const SizedBox(height: 16),

                  // Backup Actions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Backup Actions',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _performBackup,
                                  icon: const Icon(Icons.cloud_upload),
                                  label: const Text('Backup Now'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _performRestore,
                                  icon: const Icon(Icons.cloud_download),
                                  label: const Text('Restore'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.rhythmMediumGray,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_stats?.lastBackupTime != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Last backup: ${_stats!.formattedLastBackupTime}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Auto-Backup Settings
                  if (_stats != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-Backup',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('Enable Auto-Backup'),
                              subtitle: const Text('Automatically backup to Google Drive'),
                              value: _stats!.autoBackupEnabled,
                              onChanged: _toggleAutoBackup,
                            ),
                            if (_stats!.autoBackupEnabled) ...[
                              ListTile(
                                title: const Text('Backup Frequency'),
                                subtitle: Text(_getFrequencyText(_stats!.backupFrequencyDays)),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: _setBackupFrequency,
                              ),
                            ],
                            const Divider(),
                            ListTile(
                              title: const Text('Database Size'),
                              trailing: Text(_stats!.formattedDatabaseSize),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Backup History
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Backup History',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_backupFiles.isEmpty)
                            const Text('No backups found')
                          else
                            ..._backupFiles.map((backup) {
                              return ListTile(
                                leading: const Icon(Icons.backup),
                                title: Text(
                                  DateFormat.yMMMd().add_jm().format(backup.createdTime),
                                ),
                                subtitle: Text(backup.formattedSize),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _deleteBackup(backup),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  String _getFrequencyText(int days) {
    switch (days) {
      case 1:
        return 'Daily';
      case 3:
        return 'Every 3 days';
      case 7:
        return 'Weekly';
      case 14:
        return 'Every 2 weeks';
      case 30:
        return 'Monthly';
      default:
        return 'Every $days days';
    }
  }
}
