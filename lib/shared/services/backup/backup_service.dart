import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'google_drive_service.dart';
import '../database/database_service.dart';

class BackupService {
  static final BackupService instance = BackupService._init();

  BackupService._init();

  final GoogleDriveService _driveService = GoogleDriveService.instance;
  final DatabaseService _dbService = DatabaseService.instance;

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

      // Get database file path
      // Note: We don't need external storage permissions for Google Drive backup
      // since we're uploading from app-specific storage directly to Google Drive
      final dbPath = await getDatabasesPath();
      final dbFile = File(join(dbPath, 'dailyrhythm.db'));

      if (!await dbFile.exists()) {
        return BackupResult(
          success: false,
          message: 'Database file not found',
        );
      }

      // Create a copy of the database to avoid locking issues
      final tempDir = Directory.systemTemp;
      final tempDbFile = File('${tempDir.path}/dailyrhythm_backup_temp.db');

      try {
        // Copy database to temp location
        await dbFile.copy(tempDbFile.path);

        // Upload the temp file to Google Drive
        final fileId = await _driveService.uploadBackup(tempDbFile);

        // Clean up temp file
        if (await tempDbFile.exists()) {
          await tempDbFile.delete();
        }

        if (fileId != null) {
          return BackupResult(
            success: true,
            message: 'Backup completed successfully',
            fileId: fileId,
          );
        } else {
          return BackupResult(
            success: false,
            message: 'Failed to upload backup',
          );
        }
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

  // Restore database from Google Drive
  Future<BackupResult> restoreFromGoogleDrive({String? fileId}) async {
    try {
      // Check if signed in
      if (!_driveService.isSignedIn) {
        return BackupResult(
          success: false,
          message: 'Not signed in to Google Drive',
        );
      }

      // Download backup file
      final backupFile = await _driveService.downloadLatestBackup();

      if (backupFile == null || !await backupFile.exists()) {
        return BackupResult(
          success: false,
          message: 'No backup found or download failed',
        );
      }

      // Get current database path
      final dbPath = await getDatabasesPath();
      final currentDbFile = File(join(dbPath, 'dailyrhythm.db'));

      // Create backup of current database before restoring
      if (await currentDbFile.exists()) {
        final backupPath = join(dbPath, 'dailyrhythm_backup_before_restore.db');
        await currentDbFile.copy(backupPath);
      }

      // Close current database
      await _dbService.close();

      // Replace current database with downloaded backup
      await backupFile.copy(currentDbFile.path);

      // Delete temporary file
      await backupFile.delete();

      // Re-initialize database
      await _dbService.database;

      return BackupResult(
        success: true,
        message: 'Restore completed successfully. Please restart the app.',
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Error during restore: $e',
      );
    }
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
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'dailyrhythm.db'));
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
