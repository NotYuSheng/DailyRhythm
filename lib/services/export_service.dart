import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'database_service.dart';
import '../models/sleep_entry.dart';
import '../models/meal_entry.dart';
import '../models/mood_entry.dart';

class ExportResult {
  final String path;
  final int totalEntries;
  final int fileCount;

  ExportResult({
    required this.path,
    required this.totalEntries,
    required this.fileCount,
  });
}

class ExportService {
  static final ExportService instance = ExportService._init();
  ExportService._init();

  final DatabaseService _db = DatabaseService.instance;

  Future<ExportResult> exportAllDataToCsv() async {
    // Get the Downloads directory for each platform
    Directory directory;

    if (Platform.isAndroid) {
      // Android: Use Downloads folder
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        // Fallback if Download doesn't exist
        final externalDir = await getExternalStorageDirectory();
        directory = externalDir ?? await getApplicationDocumentsDirectory();
      }
    } else if (Platform.isIOS) {
      // iOS: Use app's documents directory (will be accessible via Files app)
      directory = await getApplicationDocumentsDirectory();
    } else if (Platform.isLinux) {
      // Linux: Use ~/Downloads
      final home = Platform.environment['HOME'] ?? '';
      directory = Directory('$home/Downloads');
      if (!await directory.exists()) {
        directory = await getApplicationDocumentsDirectory();
      }
    } else {
      // Fallback for other platforms
      directory = await getApplicationDocumentsDirectory();
    }

    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final exportDir = Directory('${directory.path}/DailyRhythm_Export_$timestamp');
    await exportDir.create(recursive: true);

    // Export each data type to separate CSV files and count entries
    int totalEntries = 0;
    int fileCount = 0;

    final sleepCount = await _exportSleepEntries(exportDir.path);
    if (sleepCount > 0) {
      totalEntries += sleepCount;
      fileCount++;
    }

    final mealCount = await _exportMealEntries(exportDir.path);
    if (mealCount > 0) {
      totalEntries += mealCount;
      fileCount++;
    }

    final moodCount = await _exportMoodEntries(exportDir.path);
    if (moodCount > 0) {
      totalEntries += moodCount;
      fileCount++;
    }

    final exerciseCount = await _exportExerciseEntries(exportDir.path);
    if (exerciseCount > 0) {
      totalEntries += exerciseCount;
      fileCount++;
    }

    final taskCount = await _exportTaskEntries(exportDir.path);
    if (taskCount > 0) {
      totalEntries += taskCount;
      fileCount++;
    }

    final activityCount = await _exportActivityEntries(exportDir.path);
    if (activityCount > 0) {
      totalEntries += activityCount;
      fileCount++;
    }

    final tagCount = await _exportTags(exportDir.path);
    if (tagCount > 0) {
      totalEntries += tagCount;
      fileCount++;
    }

    return ExportResult(
      path: exportDir.path,
      totalEntries: totalEntries,
      fileCount: fileCount,
    );
  }

  Future<int> _exportSleepEntries(String dirPath) async {
    final entries = await _db.getAllSleepEntries();
    if (entries.isEmpty) return 0;

    final List<List<dynamic>> rows = [
      ['ID', 'Date', 'Wake Up Time', 'Sleep Time', 'Total Hours', 'Nap Hours', 'Tags']
    ];

    for (final entry in entries) {
      rows.add([
        entry.id ?? '',
        entry.date.toIso8601String(),
        entry.wakeUpTime?.toIso8601String() ?? '',
        entry.sleepTime?.toIso8601String() ?? '',
        entry.totalHours ?? '',
        entry.napHours ?? '',
        entry.tags.join(';'),
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final file = File('$dirPath/sleep_entries.csv');
    await file.writeAsString(csv);
    return entries.length;
  }

  Future<int> _exportMealEntries(String dirPath) async {
    final entries = await _db.getAllMealEntries();
    if (entries.isEmpty) return 0;

    final List<List<dynamic>> rows = [
      ['ID', 'Date', 'Time', 'Name', 'Quantity', 'Price', 'Calories', 'Tags', 'Notes']
    ];

    for (final entry in entries) {
      rows.add([
        entry.id ?? '',
        entry.date.toIso8601String(),
        entry.time.toIso8601String(),
        entry.name,
        entry.quantity,
        entry.price,
        entry.calories ?? '',
        entry.tags.join(';'),
        entry.notes ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final file = File('$dirPath/meal_entries.csv');
    await file.writeAsString(csv);
    return entries.length;
  }

  Future<int> _exportMoodEntries(String dirPath) async {
    final now = DateTime.now();
    final oneYearAgo = now.subtract(const Duration(days: 365));
    final entries = await _db.getMoodEntriesByDateRange(oneYearAgo, now);
    if (entries.isEmpty) return 0;

    final List<List<dynamic>> rows = [
      ['ID', 'Date', 'Timestamp', 'Mood Level', 'Emoji', 'Notes']
    ];

    for (final entry in entries) {
      rows.add([
        entry.id ?? '',
        entry.date.toIso8601String(),
        entry.timestamp.toIso8601String(),
        entry.moodLevel,
        entry.emoji,
        entry.notes ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final file = File('$dirPath/mood_entries.csv');
    await file.writeAsString(csv);
    return entries.length;
  }

  Future<int> _exportExerciseEntries(String dirPath) async {
    final List<dynamic> allEntries = [];
    final now = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final entries = await _db.getExerciseEntriesByDate(date);
      allEntries.addAll(entries);
    }

    if (allEntries.isEmpty) return 0;

    final List<List<dynamic>> rows = [
      [
        'ID', 'Date', 'Timestamp', 'Type', 'Run Type', 'Distance',
        'Duration', 'Pace', 'Interval Distance', 'Interval Time',
        'Rest Time', 'Interval Count', 'Exercise Name', 'Equipment Type',
        'Reps', 'Weight', 'Sets', 'Notes'
      ]
    ];

    for (final entry in allEntries) {
      rows.add([
        entry.id ?? '',
        entry.date.toIso8601String(),
        entry.timestamp.toIso8601String(),
        entry.type,
        entry.runType ?? '',
        entry.distance ?? '',
        entry.duration ?? '',
        entry.pace ?? '',
        entry.intervalDistance ?? '',
        entry.intervalTime ?? '',
        entry.restTime ?? '',
        entry.intervalCount ?? '',
        entry.exerciseName ?? '',
        entry.equipmentType ?? '',
        entry.reps ?? '',
        entry.weight ?? '',
        entry.sets ?? '',
        entry.notes ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final file = File('$dirPath/exercise_entries.csv');
    await file.writeAsString(csv);
    return allEntries.length;
  }

  Future<int> _exportTaskEntries(String dirPath) async {
    final List<dynamic> allEntries = [];
    final now = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final entries = await _db.getTaskEntriesByDate(date);
      allEntries.addAll(entries);
    }

    if (allEntries.isEmpty) return 0;

    final List<List<dynamic>> rows = [
      ['ID', 'Date', 'Timestamp', 'Task Type', 'Notes']
    ];

    for (final entry in allEntries) {
      rows.add([
        entry.id ?? '',
        entry.date.toIso8601String(),
        entry.timestamp.toIso8601String(),
        entry.taskType,
        entry.notes ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final file = File('$dirPath/task_entries.csv');
    await file.writeAsString(csv);
    return allEntries.length;
  }

  Future<int> _exportActivityEntries(String dirPath) async {
    final List<dynamic> allEntries = [];
    final now = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final entries = await _db.getActivityEntriesByDate(date);
      allEntries.addAll(entries);
    }

    if (allEntries.isEmpty) return 0;

    final List<List<dynamic>> rows = [
      ['ID', 'Date', 'Timestamp', 'Tag ID', 'Notes']
    ];

    for (final entry in allEntries) {
      rows.add([
        entry.id ?? '',
        entry.date.toIso8601String(),
        entry.timestamp.toIso8601String(),
        entry.tagId,
        entry.notes ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final file = File('$dirPath/activity_entries.csv');
    await file.writeAsString(csv);
    return allEntries.length;
  }

  Future<int> _exportTags(String dirPath) async {
    final tags = await _db.getAllTags();
    if (tags.isEmpty) return 0;

    final List<List<dynamic>> rows = [
      ['ID', 'Name', 'Emoji', 'Category', 'Color', 'Sort Order']
    ];

    for (final tag in tags) {
      rows.add([
        tag.id ?? '',
        tag.name,
        tag.emoji,
        tag.category,
        tag.color ?? '',
        tag.sortOrder ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final file = File('$dirPath/tags.csv');
    await file.writeAsString(csv);
    return tags.length;
  }

  // ==================== Import Methods ====================

  Future<int> importDataFromCsv() async {
    // Let user pick a directory
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory == null) {
      // User cancelled the picker
      return 0;
    }

    final dir = Directory(selectedDirectory);
    if (!await dir.exists()) {
      throw Exception('Selected directory does not exist');
    }

    int totalImported = 0;

    // Import each file type
    totalImported += await _importSleepEntries('$selectedDirectory/sleep_entries.csv');
    totalImported += await _importMealEntries('$selectedDirectory/meal_entries.csv');
    totalImported += await _importMoodEntries('$selectedDirectory/mood_entries.csv');
    // Note: Tags, exercises, tasks, and activities can be added later

    return totalImported;
  }

  Future<int> _importSleepEntries(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return 0;

    try {
      final csvString = await file.readAsString();
      final rows = const CsvToListConverter().convert(csvString);

      // Skip header row
      int imported = 0;
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        try {
          final entry = SleepEntry(
            date: DateTime.parse(row[1] as String),
            wakeUpTime: row[2].toString().isNotEmpty ? DateTime.parse(row[2] as String) : null,
            sleepTime: row[3].toString().isNotEmpty ? DateTime.parse(row[3] as String) : null,
            totalHours: row[4].toString().isNotEmpty ? double.parse(row[4].toString()) : null,
            napHours: row[5].toString().isNotEmpty ? double.parse(row[5].toString()) : null,
            tags: row[6].toString().isNotEmpty ? row[6].toString().split(';') : [],
          );
          await _db.createSleepEntry(entry);
          imported++;
        } catch (e) {
          // Skip invalid rows
          continue;
        }
      }
      return imported;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _importMealEntries(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return 0;

    try {
      final csvString = await file.readAsString();
      final rows = const CsvToListConverter().convert(csvString);

      int imported = 0;
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        try {
          final entry = MealEntry(
            date: DateTime.parse(row[1] as String),
            time: DateTime.parse(row[2] as String),
            name: row[3] as String,
            quantity: int.parse(row[4].toString()),
            price: double.parse(row[5].toString()),
            calories: row[6].toString().isNotEmpty ? int.parse(row[6].toString()) : null,
            tags: row[7].toString().isNotEmpty ? row[7].toString().split(';') : [],
            notes: row[8].toString().isNotEmpty ? row[8] as String : null,
          );
          await _db.createMealEntry(entry);
          imported++;
        } catch (e) {
          continue;
        }
      }
      return imported;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _importMoodEntries(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return 0;

    try {
      final csvString = await file.readAsString();
      final rows = const CsvToListConverter().convert(csvString);

      int imported = 0;
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        try {
          final entry = MoodEntry(
            date: DateTime.parse(row[1] as String),
            timestamp: DateTime.parse(row[2] as String),
            moodLevel: int.parse(row[3].toString()),
            emoji: row[4] as String,
            notes: row[5].toString().isNotEmpty ? row[5] as String : null,
          );
          await _db.createMoodEntry(entry);
          imported++;
        } catch (e) {
          continue;
        }
      }
      return imported;
    } catch (e) {
      return 0;
    }
  }
}
