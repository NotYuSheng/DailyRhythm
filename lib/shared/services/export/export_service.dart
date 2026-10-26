import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../database/database_service.dart';
import '../../utils/date_utils.dart';
import '../../../features/sleep/data/models/sleep_entry.dart';
import '../../../features/meals/data/models/meal_entry.dart';
import '../../../features/exercise/data/models/exercise_entry.dart';
import '../../../features/tags/data/models/tag.dart';
import '../../models/mood_entry.dart';
import '../../models/nap_entry.dart';
import '../../models/task_entry.dart';
import '../../models/activity_entry.dart';

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

class ImportResult {
  /// Rows added to the database.
  int imported = 0;

  /// Rows skipped because an identical entry already exists.
  int duplicates = 0;

  /// Rows that could not be parsed.
  int invalid = 0;

  /// Whether any recognised export file was found.
  bool foundFiles = false;
}

/// Exports every table to CSV and imports those files back.
///
/// All rows are exported regardless of age. Import is idempotent: rows that
/// already exist are skipped, so importing the same folder twice is safe.
/// Activities are matched to tags by name, so they survive a fresh install
/// where tag IDs differ.
class ExportService {
  static final ExportService instance = ExportService._init();
  ExportService._init();

  final DatabaseService _db = DatabaseService.instance;

  static const _converter = ListToCsvConverter();
  // Keep every field as text; numbers are parsed explicitly per column.
  static const _parser = CsvToListConverter(shouldParseNumbers: false);

  /// Builds a zip of every table and asks the user where to save it.
  ///
  /// The system save dialog (Storage Access Framework on Android) is used
  /// instead of writing to Downloads directly: on Android 11+ files written
  /// straight to Downloads can't be read back after a reinstall, which is
  /// when an export is most needed. Returns null if the user cancels.
  Future<ExportResult?> exportAllData() async {
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final (:bytes, :summary) = await buildExportZip();

    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save DailyRhythm export',
      fileName: 'DailyRhythm_Export_$timestamp.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
      bytes: bytes,
    );
    if (savedPath == null) return null;

    // On desktop the dialog only picks a path; mobile writes the bytes itself.
    if (!Platform.isAndroid && !Platform.isIOS) {
      await File(savedPath).writeAsBytes(bytes);
    }
    return ExportResult(path: savedPath, totalEntries: summary.totalEntries, fileCount: summary.fileCount);
  }

  /// Exports every table as CSV files inside a zip archive.
  Future<({Uint8List bytes, ExportResult summary})> buildExportZip() async {
    final dir = await Directory.systemTemp.createTemp('dailyrhythm_export');
    try {
      final summary = await exportToDirectory(dir);
      final archive = Archive();
      for (final file in dir.listSync().whereType<File>()) {
        archive.addFile(ArchiveFile.bytes(file.uri.pathSegments.last, await file.readAsBytes()));
      }
      return (bytes: ZipEncoder().encodeBytes(archive), summary: summary);
    } finally {
      await dir.delete(recursive: true);
    }
  }

  /// Writes one CSV per table into [exportDir], creating it if needed.
  Future<ExportResult> exportToDirectory(Directory exportDir) async {
    await exportDir.create(recursive: true);

    final tags = await _db.getAllTags();
    final tagsById = {for (final t in tags) t.id: t};

    final files = <String, List<List<dynamic>>>{
      'sleep_entries.csv': [
        ['ID', 'Date', 'Wake Up Time', 'Sleep Time', 'Total Hours', 'Nap Hours', 'Tags'],
        for (final e in await _db.getAllSleepEntries())
          [
            e.id ?? '',
            e.date.toIso8601String(),
            e.wakeUpTime?.toIso8601String() ?? '',
            e.sleepTime?.toIso8601String() ?? '',
            e.totalHours ?? '',
            e.napHours ?? '',
            e.tags.join(';'),
          ],
      ],
      'nap_entries.csv': [
        ['ID', 'Date', 'Start Time', 'Duration Hours', 'Tags'],
        for (final e in await _db.getAllNapEntries())
          [e.id ?? '', e.date.toIso8601String(), e.startTime.toIso8601String(), e.durationHours, e.tags.join(';')],
      ],
      'meal_entries.csv': [
        ['ID', 'Date', 'Time', 'Name', 'Quantity', 'Price', 'Calories', 'Tags', 'Notes'],
        for (final e in await _db.getAllMealEntries())
          [
            e.id ?? '',
            e.date.toIso8601String(),
            e.time.toIso8601String(),
            e.name,
            e.quantity,
            e.price ?? '',
            e.calories ?? '',
            e.tags.join(';'),
            e.notes ?? '',
          ],
      ],
      'mood_entries.csv': [
        ['ID', 'Date', 'Timestamp', 'Mood Level', 'Emoji', 'Notes'],
        for (final e in await _db.getAllMoodEntries())
          [e.id ?? '', e.date.toIso8601String(), e.timestamp.toIso8601String(), e.moodLevel, e.emoji, e.notes ?? ''],
      ],
      // Durations are written in seconds and enums by name so they parse back.
      'exercise_entries.csv': [
        [
          'ID', 'Date', 'Timestamp', 'Type', 'Run Type', 'Distance',
          'Duration Seconds', 'Pace Seconds', 'Interval Distance Seconds', 'Interval Time Seconds',
          'Rest Time Seconds', 'Interval Count', 'Exercise Name', 'Equipment Type',
          'Reps', 'Weight', 'Sets', 'Notes'
        ],
        for (final e in await _db.getAllExerciseEntries())
          [
            e.id ?? '',
            e.date.toIso8601String(),
            e.timestamp.toIso8601String(),
            e.type.name,
            e.runType?.name ?? '',
            e.distance ?? '',
            e.duration?.inSeconds ?? '',
            e.pace?.inSeconds ?? '',
            e.intervalDistance?.inSeconds ?? '',
            e.intervalTime?.inSeconds ?? '',
            e.restTime?.inSeconds ?? '',
            e.intervalCount ?? '',
            e.exerciseName ?? '',
            e.equipmentType?.name ?? '',
            e.reps ?? '',
            e.weight ?? '',
            e.sets ?? '',
            e.notes ?? '',
          ],
      ],
      'task_entries.csv': [
        ['ID', 'Date', 'Timestamp', 'Task Type', 'Notes'],
        for (final e in await _db.getAllTaskEntries())
          [e.id ?? '', e.date.toIso8601String(), e.timestamp.toIso8601String(), e.taskType.name, e.notes ?? ''],
      ],
      'activity_entries.csv': [
        ['ID', 'Date', 'Timestamp', 'Tag ID', 'Notes', 'Tag Name'],
        for (final e in await _db.getAllActivityEntries())
          [
            e.id ?? '',
            e.date.toIso8601String(),
            e.timestamp.toIso8601String(),
            e.tagId,
            e.notes ?? '',
            tagsById[e.tagId]?.name ?? '',
          ],
      ],
      'tag_categories.csv': [
        ['ID', 'Name', 'Color', 'Sort Order'],
        for (final c in await _db.getAllTagCategories()) [c.id ?? '', c.name, c.color ?? '', c.sortOrder ?? ''],
      ],
      'tags.csv': [
        ['ID', 'Name', 'Emoji', 'Category', 'Color', 'Sort Order'],
        for (final t in tags) [t.id ?? '', t.name, t.emoji, t.category, t.color ?? '', t.sortOrder ?? ''],
      ],
    };

    int totalEntries = 0;
    int fileCount = 0;
    for (final MapEntry(key: name, value: rows) in files.entries) {
      if (rows.length <= 1) continue;
      await File('${exportDir.path}/$name').writeAsString(_converter.convert(rows));
      totalEntries += rows.length - 1;
      fileCount++;
    }

    return ExportResult(
      path: exportDir.path,
      totalEntries: totalEntries,
      fileCount: fileCount,
    );
  }

  // ==================== Import Methods ====================

  /// Lets the user pick an export zip (or individual CSV files from an
  /// older export folder) and imports it. Returns null if cancelled.
  Future<ImportResult?> importData() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose a DailyRhythm export',
      type: FileType.custom,
      allowedExtensions: ['zip', 'csv'],
      allowMultiple: true,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return null;

    final dir = await Directory.systemTemp.createTemp('dailyrhythm_import');
    try {
      for (final file in picked.files) {
        final bytes = file.bytes ?? await File(file.path!).readAsBytes();
        if (file.name.toLowerCase().endsWith('.zip')) {
          await _extractZip(bytes, dir);
        } else {
          await File('${dir.path}/${file.name}').writeAsBytes(bytes);
        }
      }
      return await importFromDirectory(dir.path);
    } finally {
      await dir.delete(recursive: true);
    }
  }

  /// Imports an export zip produced by [buildExportZip].
  Future<ImportResult> importFromZipBytes(List<int> bytes) async {
    final dir = await Directory.systemTemp.createTemp('dailyrhythm_import');
    try {
      await _extractZip(bytes, dir);
      return await importFromDirectory(dir.path);
    } finally {
      await dir.delete(recursive: true);
    }
  }

  /// Writes the CSV files in a zip into [dir], ignoring folders inside the
  /// archive so a re-zipped export folder also works.
  static Future<void> _extractZip(List<int> bytes, Directory dir) async {
    for (final entry in ZipDecoder().decodeBytes(bytes)) {
      final name = entry.name.split('/').last;
      if (!entry.isFile || !name.toLowerCase().endsWith('.csv')) continue;
      await File('${dir.path}/$name').writeAsBytes(entry.content);
    }
  }

  /// Imports every recognised CSV file in [dirPath].
  Future<ImportResult> importFromDirectory(String dirPath) async {
    if (!await Directory(dirPath).exists()) {
      throw Exception('Selected directory does not exist');
    }

    final result = ImportResult();

    // Categories and tags first so activities can be matched to them.
    await _importRows(dirPath, 'tag_categories.csv', result, (row) async {
      final name = _text(row, 1)!;
      final existing = await _db.getAllTagCategories();
      if (existing.any((c) => c.name == name)) return false;
      await _db.createTagCategory(TagCategory(name: name, color: _text(row, 2), sortOrder: _int(row, 3)));
      return true;
    });

    // Maps the exporting device's tag IDs to this device's tags.
    final exportedTagNames = <int, String>{};
    await _importRows(dirPath, 'tags.csv', result, (row) async {
      final name = _text(row, 1)!;
      final exportedId = _int(row, 0);
      if (exportedId != null) exportedTagNames[exportedId] = name;
      final existing = await _db.getAllTags();
      if (existing.any((t) => t.name == name)) return false;
      await _db.createTag(Tag(
        name: name,
        emoji: _text(row, 2) ?? 'tag',
        category: _text(row, 3) ?? 'General',
        color: _text(row, 4),
        sortOrder: _int(row, 5),
      ));
      return true;
    });

    await _importRows(dirPath, 'sleep_entries.csv', result, (row) async {
      final entry = SleepEntry(
        date: _day(row, 1)!,
        wakeUpTime: _dateTime(row, 2),
        sleepTime: _dateTime(row, 3),
        totalHours: _double(row, 4),
        napHours: _double(row, 5),
        tags: _list(row, 6),
      );
      if (await _db.getSleepEntryByDate(entry.date) != null) return false;
      await _db.createSleepEntry(entry);
      return true;
    });

    await _importRows(dirPath, 'nap_entries.csv', result, (row) async {
      final entry = NapEntry(
        date: _day(row, 1)!,
        startTime: _dateTime(row, 2)!,
        durationHours: _double(row, 3)!,
        tags: _list(row, 4),
      );
      if (await _exists('nap_entries', entry.toMap(), ['date', 'startTime'])) return false;
      await _db.createNapEntry(entry);
      return true;
    });

    await _importRows(dirPath, 'meal_entries.csv', result, (row) async {
      final entry = MealEntry(
        date: _day(row, 1)!,
        time: _dateTime(row, 2)!,
        name: _text(row, 3)!,
        quantity: _int(row, 4) ?? 1,
        price: _double(row, 5),
        calories: _int(row, 6),
        tags: _list(row, 7),
        notes: _text(row, 8),
      );
      if (await _exists('meal_entries', entry.toMap(), ['date', 'time', 'name'])) return false;
      await _db.createMealEntry(entry);
      return true;
    });

    await _importRows(dirPath, 'mood_entries.csv', result, (row) async {
      final entry = MoodEntry(
        date: _day(row, 1)!,
        timestamp: _dateTime(row, 2)!,
        moodLevel: _int(row, 3)!,
        emoji: _text(row, 4) ?? '',
        notes: _text(row, 5),
      );
      if (await _db.getMoodEntryByDate(entry.date) != null) return false;
      await _db.createMoodEntry(entry);
      return true;
    });

    await _importRows(dirPath, 'exercise_entries.csv', result, (row) async {
      final entry = ExerciseEntry(
        date: _day(row, 1)!,
        timestamp: _dateTime(row, 2)!,
        type: _enum(ExerciseType.values, _text(row, 3))!,
        runType: _enum(RunType.values, _text(row, 4)),
        distance: _double(row, 5),
        duration: _duration(row, 6),
        pace: _duration(row, 7),
        intervalDistance: _duration(row, 8),
        intervalTime: _duration(row, 9),
        restTime: _duration(row, 10),
        intervalCount: _int(row, 11),
        exerciseName: _text(row, 12),
        equipmentType: _enum(EquipmentType.values, _text(row, 13)),
        reps: _int(row, 14),
        weight: _double(row, 15),
        sets: _int(row, 16),
        notes: _text(row, 17),
      );
      if (await _exists('exercise_entries', entry.toMap(), ['date', 'timestamp', 'type'])) return false;
      await _db.createExerciseEntry(entry);
      return true;
    });

    await _importRows(dirPath, 'task_entries.csv', result, (row) async {
      final entry = TaskEntry(
        date: _day(row, 1)!,
        timestamp: _dateTime(row, 2)!,
        taskType: _enum(TaskType.values, _text(row, 3))!,
        notes: _text(row, 4),
      );
      if (await _exists('task_entries', entry.toMap(), ['date', 'timestamp', 'taskType'])) return false;
      await _db.createTaskEntry(entry);
      return true;
    });

    final tagIdsByName = {for (final t in await _db.getAllTags()) t.name: t.id!};
    await _importRows(dirPath, 'activity_entries.csv', result, (row) async {
      // Prefer the tag name column; older exports only have the tag ID.
      final tagName = _text(row, 5) ?? exportedTagNames[_int(row, 3)];
      final tagId = tagIdsByName[tagName];
      if (tagId == null) throw const FormatException('Unknown tag');
      final entry = ActivityEntry(
        date: _day(row, 1)!,
        timestamp: _dateTime(row, 2)!,
        tagId: tagId,
        notes: _text(row, 4),
      );
      if (await _exists('activity_entries', entry.toMap(), ['date', 'tagId'])) return false;
      await _db.createActivityEntry(entry);
      return true;
    });

    return result;
  }

  /// Parses [fileName] and runs [importRow] on each data row. [importRow]
  /// returns false for a duplicate; a thrown error counts the row as invalid.
  Future<void> _importRows(
    String dirPath,
    String fileName,
    ImportResult result,
    Future<bool> Function(List<dynamic> row) importRow,
  ) async {
    final file = File('$dirPath/$fileName');
    if (!await file.exists()) return;
    result.foundFiles = true;

    final rows = _parser.convert(await file.readAsString());
    for (final row in rows.skip(1)) {
      if (row.every((cell) => cell.toString().isEmpty)) continue;
      try {
        if (await importRow(row)) {
          result.imported++;
        } else {
          result.duplicates++;
        }
      } catch (_) {
        result.invalid++;
      }
    }
  }

  Future<bool> _exists(String table, Map<String, dynamic> map, List<String> keys) {
    final values = {for (final k in keys) k: map[k]};
    values['date'] = dayOf(DateTime.parse(map['date'] as String)).toIso8601String();
    return _db.rowExists(table, values);
  }

  // ---- Cell parsing helpers; an empty cell is null. ----

  static String? _text(List<dynamic> row, int i) {
    if (i >= row.length) return null;
    final value = row[i].toString();
    return value.isEmpty ? null : value;
  }

  static int? _int(List<dynamic> row, int i) {
    final text = _text(row, i);
    return text == null ? null : int.parse(text);
  }

  static double? _double(List<dynamic> row, int i) {
    final text = _text(row, i);
    return text == null ? null : double.parse(text);
  }

  static DateTime? _dateTime(List<dynamic> row, int i) {
    final text = _text(row, i);
    return text == null ? null : DateTime.parse(text);
  }

  static DateTime? _day(List<dynamic> row, int i) {
    final value = _dateTime(row, i);
    return value == null ? null : dayOf(value);
  }

  /// Seconds, or the `H:MM:SS.ffffff` form written by older exports.
  static Duration? _duration(List<dynamic> row, int i) {
    final text = _text(row, i);
    if (text == null) return null;
    if (!text.contains(':')) return Duration(seconds: int.parse(text));
    final parts = text.split(':');
    return Duration(
      hours: int.parse(parts[0]),
      minutes: int.parse(parts[1]),
      microseconds: (double.parse(parts[2]) * Duration.microsecondsPerSecond).round(),
    );
  }

  static List<String> _list(List<dynamic> row, int i) => _text(row, i)?.split(';') ?? [];

  /// Accepts `name` and the older `EnumType.name` form.
  static T? _enum<T extends Enum>(List<T> values, String? text) {
    if (text == null) return null;
    final name = text.split('.').last;
    return values.firstWhere((v) => v.name == name);
  }
}
