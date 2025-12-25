import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_config.dart';

class GoogleDriveService {
  static final GoogleDriveService instance = GoogleDriveService._init();

  GoogleDriveService._init();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      drive.DriveApi.driveAppdataScope,
    ],
    serverClientId: AppConfig.googleServerClientId,
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  // Initialize and check if user is already signed in
  Future<void> initialize() async {
    // Check if platform is supported
    if (!_isPlatformSupported()) {
      debugPrint('Google Sign-In not supported on this platform');
      return;
    }

    _googleSignIn.onCurrentUserChanged.listen((account) {
      _currentUser = account;
    });

    // Try to sign in silently
    try {
      await _googleSignIn.signInSilently();
    } catch (e) {
      // Silent sign-in failed, user needs to sign in manually
      debugPrint('Silent sign-in failed: $e');
    }
  }

  // Check if current platform supports Google Sign-In
  bool _isPlatformSupported() {
    // Google Sign-In is supported on Android, iOS, and Web
    // Desktop platforms (Linux, Windows, macOS) have limited/no support
    if (kIsWeb) return true;

    return defaultTargetPlatform == TargetPlatform.android ||
           defaultTargetPlatform == TargetPlatform.iOS;
  }

  // Sign in to Google
  Future<GoogleSignInAccount?> signIn() async {
    if (!_isPlatformSupported()) {
      throw UnsupportedError(
        'Google Sign-In is not supported on this platform. '
        'Please run on Android, iOS, or Web.',
      );
    }

    try {
      final account = await _googleSignIn.signIn();
      _currentUser = account;

      if (account != null) {
        // Initialize Drive API
        final authClient = await _googleSignIn.authenticatedClient();
        if (authClient != null) {
          _driveApi = drive.DriveApi(authClient);
        }
      }

      return account;
    } catch (e) {
      debugPrint('Error signing in: $e');
      return null;
    }
  }

  // Sign out from Google
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
      _driveApi = null;
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  // Upload database file to Google Drive
  Future<String?> uploadBackup(File dbFile) async {
    if (_driveApi == null) {
      final authClient = await _googleSignIn.authenticatedClient();
      if (authClient != null) {
        _driveApi = drive.DriveApi(authClient);
      } else {
        throw Exception('Not authenticated');
      }
    }

    try {
      // Check if backup folder exists, create if not
      final folderId = await _getOrCreateBackupFolder();

      // Create file metadata
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'dailyrhythm_backup_$timestamp.db';

      final driveFile = drive.File();
      driveFile.name = fileName;
      driveFile.parents = [folderId];
      driveFile.description = 'DailyRhythm database backup';

      // Upload file
      final media = drive.Media(dbFile.openRead(), dbFile.lengthSync());
      final response = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
      );

      // Save last backup time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_backup_time', DateTime.now().toIso8601String());
      await prefs.setString('last_backup_file_id', response.id ?? '');

      return response.id;
    } catch (e) {
      debugPrint('Error uploading backup: $e');
      return null;
    }
  }

  // Download latest backup from Google Drive
  Future<File?> downloadLatestBackup() async {
    if (_driveApi == null) {
      final authClient = await _googleSignIn.authenticatedClient();
      if (authClient != null) {
        _driveApi = drive.DriveApi(authClient);
      } else {
        throw Exception('Not authenticated');
      }
    }

    try {
      // Get backup folder
      final folderId = await _getOrCreateBackupFolder();

      // List all backup files, sorted by creation time
      final fileList = await _driveApi!.files.list(
        q: "'$folderId' in parents and name contains 'dailyrhythm_backup_' and trashed=false",
        orderBy: 'createdTime desc',
        spaces: 'drive',
        $fields: 'files(id, name, createdTime)',
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        return null;
      }

      // Get the most recent backup
      final latestFile = fileList.files!.first;
      final fileId = latestFile.id;

      if (fileId == null) {
        return null;
      }

      // Download the file
      final drive.Media media = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_restore.db');

      final sink = tempFile.openWrite();
      await media.stream.pipe(sink);

      return tempFile;
    } catch (e) {
      debugPrint('Error downloading backup: $e');
      return null;
    }
  }

  // Get all backups from Google Drive
  Future<List<BackupFile>> listBackups() async {
    if (_driveApi == null) {
      final authClient = await _googleSignIn.authenticatedClient();
      if (authClient != null) {
        _driveApi = drive.DriveApi(authClient);
      } else {
        throw Exception('Not authenticated');
      }
    }

    try {
      final folderId = await _getOrCreateBackupFolder();

      final fileList = await _driveApi!.files.list(
        q: "'$folderId' in parents and name contains 'dailyrhythm_backup_' and trashed=false",
        orderBy: 'createdTime desc',
        spaces: 'drive',
        $fields: 'files(id, name, createdTime, size)',
      );

      if (fileList.files == null) {
        return [];
      }

      return fileList.files!.map((file) {
        return BackupFile(
          id: file.id ?? '',
          name: file.name ?? '',
          createdTime: file.createdTime ?? DateTime.now(),
          size: int.tryParse(file.size ?? '0') ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error listing backups: $e');
      return [];
    }
  }

  // Delete a specific backup
  Future<bool> deleteBackup(String fileId) async {
    if (_driveApi == null) {
      final authClient = await _googleSignIn.authenticatedClient();
      if (authClient != null) {
        _driveApi = drive.DriveApi(authClient);
      } else {
        throw Exception('Not authenticated');
      }
    }

    try {
      await _driveApi!.files.delete(fileId);
      return true;
    } catch (e) {
      debugPrint('Error deleting backup: $e');
      return false;
    }
  }

  // Get or create the backup folder in Google Drive
  Future<String> _getOrCreateBackupFolder() async {
    try {
      // Search for existing folder
      final fileList = await _driveApi!.files.list(
        q: "name='DailyRhythm_Backups' and mimeType='application/vnd.google-apps.folder' and trashed=false",
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id!;
      }

      // Create new folder
      final folder = drive.File();
      folder.name = 'DailyRhythm_Backups';
      folder.mimeType = 'application/vnd.google-apps.folder';

      final response = await _driveApi!.files.create(folder);
      return response.id!;
    } catch (e) {
      debugPrint('Error getting/creating backup folder: $e');
      rethrow;
    }
  }

  // Get last backup time from shared preferences
  Future<DateTime?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString('last_backup_time');
    if (timeString != null) {
      return DateTime.parse(timeString);
    }
    return null;
  }
}

// Model for backup file info
class BackupFile {
  final String id;
  final String name;
  final DateTime createdTime;
  final int size;

  BackupFile({
    required this.id,
    required this.name,
    required this.createdTime,
    required this.size,
  });

  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
