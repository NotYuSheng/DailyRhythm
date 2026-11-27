import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'google_drive_service.dart';
import '../database/database_service.dart';

class BackupService {
  static final BackupService instance = BackupService._init();

  BackupService._init();

  final GoogleDriveService _driveService = GoogleDriveService.instance;
  final DatabaseService _dbService = DatabaseService.instance;

  /// Number of backups kept in Google Drive; older ones are deleted.
  static const int backupsToKeep = 10;

  // Backup database to Google Drive
  Future<BackupResult> backupToGoogleDrive() async {
    try {
      // Check if signed in
      if (!_driveService.isSignedIn) {
        return BackupResult(
          success: false,
          message: 'Not signed in to Google Drive',
        );
      }

      // Note: We don't need external storage permissions for Google Drive backup
      // since we're uploading from app-specific storage directly to Google Drive
      final dbFile = await _databaseFile();

      if (!await dbFile.exists()) {
        return BackupResult(
          success: false,
          message: 'Database file not found',
        );
      }

      final tempDbFile = File('${Directory.systemTemp.path}/dailyrhythm_backup_temp.db');

      try {
        // A snapshot from the open connection: closing it would break
        // queries the app is running, such as at launch.
        await _dbService.snapshotTo(tempDbFile.path);

        final fileId = await _driveService.uploadBackup(tempDbFile);
        if (fileId == null) {
          return BackupResult(
            success: false,
            message: 'Failed to upload backup',
          );
        }

        // The backup is saved; failing to tidy old ones isn't a failure.
        try {
          await _driveService.pruneBackups(keep: backupsToKeep);
        } catch (e) {
          debugPrint('Pruning old backups failed: $e');
        }
        return BackupResult(
          success: true,
          message: 'Backup completed successfully',
          fileId: fileId,
        );
      } finally {
        // Ensure temp file is cleaned up
        if (await tempDbFile.exists()) {
          await tempDbFile.delete();
        }
      }
    } catch (e) {
      debugPrint('Backup error: $e');
      return BackupResult(
        success: false,
        message: 'Error during backup: $e',
      );
    }
  }

  /// Restores the backup with [fileId], or the newest backup if null.
  Future<BackupResult> restoreFromGoogleDrive({String? fileId}) async {
    try {
      // Check if signed in
      if (!_driveService.isSignedIn) {
        return BackupResult(
          success: false,
          message: 'Not signed in to Google Drive',
        );
      }

      final backupFile = fileId == null
          ? await _driveService.downloadLatestBackup()
          : await _driveService.downloadBackup(fileId);

      if (backupFile == null || !await backupFile.exists()) {
        return BackupResult(
          success: false,
          message: 'No backup found or download failed',
        );
      }

      try {
        return await restoreFromFile(backupFile);
      } finally {
        if (await backupFile.exists()) {
          await backupFile.delete();
        }
      }
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Error during restore: $e',
      );
    }
  }

  /// Replaces the current database with [backupFile].
  ///
  /// The file is checked before anything is replaced, and the current
  /// database is kept as `dailyrhythm_backup_before_restore.db`. If the
  /// restored database fails to open, the previous one is put back.
  @visibleForTesting
  Future<BackupResult> restoreFromFile(File backupFile) async {
    final problem = await DatabaseService.checkRestorable(backupFile.path);
    if (problem != null) {
      return BackupResult(success: false, message: problem);
    }

    final currentDbFile = await _databaseFile();
    final previousCopy = File(join(currentDbFile.parent.path, 'dailyrhythm_backup_before_restore.db'));

    await _dbService.close();
    // With no current data, an older safety copy stays as it is: it may be
    // the only copy left of earlier data.
    final hadData = await currentDbFile.exists();
    if (hadData) {
      await currentDbFile.copy(previousCopy.path);
    }
    await backupFile.copy(currentDbFile.path);

    try {
      // Opening runs any upgrades needed for an older backup.
      await _dbService.database;
    } catch (e) {
      await _dbService.close();
      // Put the previous data back, or with none, start empty rather than
      // keep a database that can't open.
      if (hadData) {
        await previousCopy.copy(currentDbFile.path);
      } else {
        await currentDbFile.delete();
      }
      try {
        await _dbService.database;
      } catch (reopen) {
        debugPrint('Reopening after a failed restore failed: $reopen');
      }
      return BackupResult(
        success: false,
        message: hadData ? 'Restore failed and your previous data was kept: $e' : 'Restore failed: $e',
      );
    }

    return BackupResult(
      success: true,
      message: 'Restore completed successfully. Please restart the app.',
    );
  }

  Future<File> _databaseFile() async {
    return File(await DatabaseService.databaseFilePath());
  }

  // Get auto-backup settings
  Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_backup_enabled') ?? false;
  }

  // Set auto-backup settings
  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup_enabled', enabled);
  }

  // Get auto-backup frequency (in days)
  Future<int> getAutoBackupFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('auto_backup_frequency') ?? 7; // Default: weekly
  }

  // Set auto-backup frequency
  Future<void> setAutoBackupFrequency(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('auto_backup_frequency', days);
  }

  // Check if auto-backup is due
  Future<bool> isBackupDue() async {
    if (!await isAutoBackupEnabled()) {
      return false;
    }

    final lastBackupTime = await _driveService.getLastBackupTime();
    if (lastBackupTime == null) {
      return true; // Never backed up
    }

    final frequency = await getAutoBackupFrequency();
    final nextBackupTime = lastBackupTime.add(Duration(days: frequency));

    return DateTime.now().isAfter(nextBackupTime);
  }

  // Perform auto-backup if due
  Future<void> performAutoBackupIfDue() async {
    if (!_driveService.isSignedIn) {
      return;
    }

    if (await isBackupDue()) {
      await backupToGoogleDrive();
    }
  }

  // Get backup statistics
  Future<BackupStats> getBackupStats() async {
    final lastBackupTime = await _driveService.getLastBackupTime();
    final autoBackupEnabled = await isAutoBackupEnabled();
    final frequency = await getAutoBackupFrequency();

    // Get database size
    final dbFile = await _databaseFile();
    int dbSize = 0;
    if (await dbFile.exists()) {
      dbSize = await dbFile.length();
    }

    return BackupStats(
      lastBackupTime: lastBackupTime,
      autoBackupEnabled: autoBackupEnabled,
      backupFrequencyDays: frequency,
      databaseSize: dbSize,
    );
  }
}

// Result model for backup/restore operations
class BackupResult {
  final bool success;
  final String message;
  final String? fileId;

  BackupResult({
    required this.success,
    required this.message,
    this.fileId,
  });
}

// Model for backup statistics
class BackupStats {
  final DateTime? lastBackupTime;
  final bool autoBackupEnabled;
  final int backupFrequencyDays;
  final int databaseSize;

  BackupStats({
    required this.lastBackupTime,
    required this.autoBackupEnabled,
    required this.backupFrequencyDays,
    required this.databaseSize,
  });

  String get formattedDatabaseSize {
    if (databaseSize < 1024) {
      return '$databaseSize B';
    } else if (databaseSize < 1024 * 1024) {
      return '${(databaseSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(databaseSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String? get formattedLastBackupTime {
    if (lastBackupTime == null) {
      return null;
    }

    final now = DateTime.now();
    final difference = now.difference(lastBackupTime!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return 'Over a month ago';
    }
  }
}
