import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_service.dart';
import '../database/schema_v13.dart';
import '../../utils/date_utils.dart';
import '../../../features/sleep/data/models/sleep_entry.dart';
import '../../../features/meals/data/models/meal_entry.dart';
import '../../../features/exercise/data/models/exercise_entry.dart';
import '../../../features/tags/data/models/tag.dart';
import '../../models/mood_entry.dart';
import '../../models/nap_entry.dart';
import '../../models/task_entry.dart';
import '../../models/activity_entry.dart';
import '../../models/day_checkin.dart';
import '../../models/daylio_raw_entry.dart';
import '../../../features/exercise/data/models/exercise_item.dart';
import '../../../features/health/data/models/health_metric.dart';
import '../../../features/journal/data/models/journal_entry.dart';
import '../../../features/meals/data/models/food_item.dart';

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

/// Called as an import applies rows: [done] of [total] so far.
typedef ImportProgress = void Function(int done, int total);

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
/// Tags and catalog items are matched by name, so they survive a fresh
/// install where IDs differ. Columns added in later versions go at the end
/// of a file, so older exports still import.
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

    final db = await _db.database;
    final tags = await _db.getAllTags();
    final tagsById = {for (final t in tags) t.id: t};
    // Catalog items and tags are referenced by name so they survive a fresh
    // install, where IDs differ.
    final foods = (await db.query('food_items', orderBy: 'name')).map(FoodItem.fromMap).toList();
    final foodNames = {for (final f in foods) f.id: f.name};
    final exercises = (await db.query('exercise_items', orderBy: 'name')).map(ExerciseItem.fromMap).toList();
    final exerciseNames = {for (final x in exercises) x.id: x.name};
    final journalTags = <int, List<String>>{};
    for (final link in await db.query('journal_entry_tags')) {
      final name = tagsById[link['tag_id']]?.name;
      if (name != null) journalTags.putIfAbsent(link['entry_id'] as int, () => []).add(name);
    }

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
        [
          'ID', 'Date', 'Time', 'Name', 'Quantity', 'Price', 'Calories', 'Tags', 'Notes',
          'Food Source', 'Food Item', 'Currency', 'Raw Text', 'Time Known',
        ],
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
            e.foodSource ?? '',
            foodNames[e.foodItemId] ?? '',
            e.currency,
            e.rawText ?? '',
            e.timeKnown ? 1 : 0,
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
          'Reps', 'Weight', 'Sets', 'Notes', 'Exercise Item', 'Raw Text',
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
            exerciseNames[e.exerciseItemId] ?? '',
            e.rawText ?? '',
          ],
      ],
      'task_entries.csv': [
        ['ID', 'Date', 'Timestamp', 'Task Type', 'Notes'],
        for (final e in await _db.getAllTaskEntries())
          [e.id ?? '', e.date.toIso8601String(), e.timestamp.toIso8601String(), e.taskType.name, e.notes ?? ''],
      ],
      'activity_entries.csv': [
        ['ID', 'Date', 'Timestamp', 'Tag ID', 'Notes', 'Tag Name', 'Severity'],
        for (final e in await _db.getAllActivityEntries())
          [
            e.id ?? '',
            e.date.toIso8601String(),
            e.timestamp.toIso8601String(),
            e.tagId,
            e.notes ?? '',
            tagsById[e.tagId]?.name ?? '',
            e.severity ?? '',
          ],
      ],
      'tag_categories.csv': [
        ['ID', 'Name', 'Color', 'Sort Order'],
        for (final c in await _db.getAllTagCategories()) [c.id ?? '', c.name, c.color ?? '', c.sortOrder ?? ''],
      ],
      'tags.csv': [
        ['ID', 'Name', 'Emoji', 'Category', 'Color', 'Sort Order', 'Kind'],
        for (final t in tags) [t.id ?? '', t.name, t.emoji, t.category, t.color ?? '', t.sortOrder ?? '', t.kind],
      ],
      'food_items.csv': [
        ['ID', 'Name', 'Aliases', 'Kcal', 'Kcal Source', 'Last Price'],
        for (final f in foods) [f.id ?? '', f.name, f.aliases.join(';'), f.kcal ?? '', f.kcalSource ?? '', f.lastPrice ?? ''],
      ],
      'exercise_items.csv': [
        ['ID', 'Name', 'Aliases', 'Category'],
        for (final x in exercises) [x.id ?? '', x.name, x.aliases.join(';'), x.category],
      ],
      'journal_entries.csv': [
        ['ID', 'Date', 'Time', 'Text', 'Mood', 'Source', 'Created At', 'Tag Names'],
        for (final j in (await db.query('journal_entries', orderBy: 'date, time, id')).map(JournalEntry.fromMap))
          [
            j.id ?? '',
            j.date.toIso8601String(),
            j.time?.toIso8601String() ?? '',
            j.text,
            j.mood ?? '',
            j.source,
            j.createdAt.toIso8601String(),
            (journalTags[j.id] ?? const []).join(';'),
          ],
      ],
      'day_checkins.csv': [
        ['Date', 'Energy', 'Stress', 'Focus', 'Plant Override'],
        for (final c in (await db.query('day_checkins', orderBy: 'date')).map(DayCheckin.fromMap))
          [c.date.toIso8601String(), c.energy ?? '', c.stress ?? '', c.focus ?? '', c.plantOverride ?? ''],
      ],
      'health_metrics.csv': [
        ['Date', 'Metric', 'Value', 'Source'],
        for (final m in (await db.query('health_metrics', orderBy: 'date, metric')).map(HealthMetric.fromMap))
          [m.date.toIso8601String(), m.metric, m.value, m.source],
      ],
      'health_workouts.csv': [
        ['Start', 'Type', 'Duration Min', 'Distance Km', 'Kcal', 'Avg HR', 'Max HR', 'Source'],
        for (final w in (await db.query('health_workouts', orderBy: 'start')).map(HealthWorkout.fromMap))
          [
            w.start.toIso8601String(), w.type, w.durationMin ?? '', w.distanceKm ?? '',
            w.kcal ?? '', w.avgHr ?? '', w.maxHr ?? '', w.source,
          ],
      ],
      'daylio_raw.csv': [
        ['Date', 'Logged Time', 'Mood', 'Activities', 'Note'],
        for (final r in (await db.query('daylio_raw', orderBy: 'date, logged_time')).map(DaylioRawEntry.fromMap))
          [r.date.toIso8601String(), r.loggedTime, r.mood ?? '', r.activities, r.note],
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
  Future<ImportResult?> importData({ImportProgress? onProgress}) async {
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
      return await importFromDirectory(dir.path, onProgress: onProgress);
    } finally {
      await dir.delete(recursive: true);
    }
  }

  /// Imports an export zip produced by [buildExportZip].
  Future<ImportResult> importFromZipBytes(List<int> bytes, {ImportProgress? onProgress}) async {
    final dir = await Directory.systemTemp.createTemp('dailyrhythm_import');
    try {
      await _extractZip(bytes, dir);
      return await importFromDirectory(dir.path, onProgress: onProgress);
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

  /// Files an import reads, in the order they are applied: categories and
  /// tags before the entries that use them, catalog items before the meals
  /// and exercises that link to them.
  static const importOrder = [
    'tag_categories.csv', 'tags.csv', 'food_items.csv', 'exercise_items.csv',
    'sleep_entries.csv', 'nap_entries.csv', 'meal_entries.csv', 'mood_entries.csv',
    'exercise_entries.csv', 'task_entries.csv', 'activity_entries.csv', 'journal_entries.csv',
    'day_checkins.csv', 'health_metrics.csv', 'health_workouts.csv', 'daylio_raw.csv',
  ];

  /// Imports every recognised CSV file in [dirPath] in one transaction, so
  /// a large import is fast and a failure leaves the database unchanged.
  Future<ImportResult> importFromDirectory(String dirPath, {ImportProgress? onProgress}) async {
    if (!await Directory(dirPath).exists()) {
      throw Exception('Selected directory does not exist');
    }

    final files = <String, List<List<dynamic>>>{};
    for (final name in importOrder) {
      final file = File('$dirPath/$name');
      if (!await file.exists()) continue;
      files[name] = [
        for (final row in _parser.convert(await file.readAsString()).skip(1))
          if (row.any((cell) => cell.toString().isNotEmpty)) row,
      ];
    }

    final result = ImportResult()..foundFiles = files.isNotEmpty;
    final total = files.values.fold(0, (sum, rows) => sum + rows.length);
    var done = 0;
    onProgress?.call(0, total);

    final db = await _db.database;
    await db.transaction((txn) async {
      final importer = _Importer(txn);
      await importer.loadExisting();
      for (final MapEntry(key: name, value: rows) in files.entries) {
        final importRow = importer.handlers[name]!;
        for (final row in rows) {
          try {
            if (await importRow(row)) {
              result.imported++;
            } else {
              result.duplicates++;
            }
          } catch (_) {
            result.invalid++;
          }
          done++;
          if (done % 250 == 0 || done == total) onProgress?.call(done, total);
        }
      }
    });
    return result;
  }
}

/// Applies rows of each export file inside one transaction. Duplicate keys
/// are loaded up front and checked in memory instead of a query per row.
class _Importer {
  _Importer(this.txn);

  final Transaction txn;

  final _categoryNames = <String>{};
  final _tagIds = <String, int>{}; // name -> ID on this device
  final _exportedTagNames = <int, String>{}; // exporting device's ID -> name
  final _foodIds = <String, int>{}; // lower-case name -> ID
  final _exerciseIds = <String, int>{};
  final _keys = <String, Set<String>>{};
  // Moments logged in the same minute can differ only by mood and tags.
  final _journalKeys = <String>{};

  /// Columns that identify a row, for skipping ones already present.
  static const _keyColumns = {
    'sleep_entries': ['date'],
    'nap_entries': ['date', 'startTime'],
    'meal_entries': ['date', 'time', 'name'],
    'mood_entries': ['date'],
    'exercise_entries': ['date', 'timestamp', 'type'],
    'task_entries': ['date', 'timestamp', 'taskType'],
    'activity_entries': ['date', 'tagId'],
    'day_checkins': ['date'],
    'health_metrics': ['date', 'metric', 'source'],
    'health_workouts': ['start', 'source'],
    'daylio_raw': ['date', 'logged_time', 'note'],
  };

  static String _key(Map<String, dynamic> row, List<String> columns) =>
      columns.map((c) => row[c]?.toString() ?? '').join('\u0001');

  static String _journalKey(Map<String, dynamic> row, Iterable<String> tagNames) =>
      '${_key(row, const ['date', 'time', 'text', 'mood'])}\u0001${(tagNames.toList()..sort()).join(';')}';

  Future<void> loadExisting() async {
    for (final row in await txn.query('tag_categories', columns: ['name'])) {
      _categoryNames.add(row['name'] as String);
    }
    for (final row in await txn.query('tags', columns: ['id', 'name'])) {
      _tagIds[row['name'] as String] = row['id'] as int;
    }
    for (final row in await txn.query('food_items', columns: ['id', 'name'])) {
      _foodIds[(row['name'] as String).toLowerCase()] = row['id'] as int;
    }
    for (final row in await txn.query('exercise_items', columns: ['id', 'name'])) {
      _exerciseIds[(row['name'] as String).toLowerCase()] = row['id'] as int;
    }
    for (final MapEntry(key: table, value: columns) in _keyColumns.entries) {
      _keys[table] = {for (final row in await txn.query(table, columns: columns)) _key(row, columns)};
    }
    final tagNames = {for (final MapEntry(:key, :value) in _tagIds.entries) value: key};
    final entryTags = <Object?, List<String>>{};
    for (final link in await txn.query('journal_entry_tags')) {
      entryTags.putIfAbsent(link['entry_id'], () => []).add(tagNames[link['tag_id']] ?? '');
    }
    for (final row in await txn.query('journal_entries')) {
      _journalKeys.add(_journalKey(row, entryTags[row['id']] ?? const []));
    }
  }

  /// Inserts [map] unless an identical row exists; false for a duplicate.
  /// Dates are stored as the start of their day.
  Future<bool> _add(String table, Map<String, dynamic> map) async {
    if (map['date'] is String) {
      map['date'] = dayOf(DateTime.parse(map['date'] as String)).toIso8601String();
    }
    final key = _key(map, _keyColumns[table]!);
    if (!_keys[table]!.add(key)) return false;
    try {
      await txn.insert(table, map);
      return true;
    } catch (_) {
      _keys[table]!.remove(key);
      rethrow;
    }
  }

  int _tagId(String? name) {
    final id = _tagIds[name];
    if (id == null) throw FormatException('Unknown tag: $name');
    return id;
  }

  late final Map<String, Future<bool> Function(List<dynamic> row)> handlers = {
    'tag_categories.csv': (row) async {
      final name = _text(row, 1)!;
      if (!_categoryNames.add(name)) return false;
      await txn.insert('tag_categories', TagCategory(name: name, color: _text(row, 2), sortOrder: _int(row, 3)).toMap());
      return true;
    },
    'tags.csv': (row) async {
      final name = _text(row, 1)!;
      final exportedId = _int(row, 0);
      if (exportedId != null) _exportedTagNames[exportedId] = name;
      if (_tagIds.containsKey(name)) return false;
      final category = _text(row, 3) ?? 'General';
      // A tag can name a category the export left out; tag screens group
      // by category, so create it rather than hide the tag.
      if (_categoryNames.add(category)) {
        await txn.insert('tag_categories', TagCategory(name: category, sortOrder: _categoryNames.length).toMap());
      }
      _tagIds[name] = await txn.insert(
        'tags',
        Tag(
          name: name,
          emoji: _text(row, 2) ?? 'tag',
          category: category,
          color: _text(row, 4),
          sortOrder: _int(row, 5),
          kind: _text(row, 6) ?? SchemaV13.kindFor(name, category),
        ).toMap(),
      );
      return true;
    },
    'food_items.csv': (row) async {
      final item = FoodItem(
        name: _text(row, 1)!,
        aliases: _list(row, 2),
        kcal: _double(row, 3),
        kcalSource: _text(row, 4),
        lastPrice: _double(row, 5),
      );
      if (_foodIds.containsKey(item.name.toLowerCase())) return false;
      _foodIds[item.name.toLowerCase()] = await txn.insert('food_items', item.toMap());
      return true;
    },
    'exercise_items.csv': (row) async {
      final item = ExerciseItem(name: _text(row, 1)!, aliases: _list(row, 2), category: _text(row, 3) ?? ExerciseItem.strength);
      if (_exerciseIds.containsKey(item.name.toLowerCase())) return false;
      _exerciseIds[item.name.toLowerCase()] = await txn.insert('exercise_items', item.toMap());
      return true;
    },
    'sleep_entries.csv': (row) => _add(
      'sleep_entries',
      SleepEntry(
        date: _day(row, 1)!,
        wakeUpTime: _dateTime(row, 2),
        sleepTime: _dateTime(row, 3),
        totalHours: _double(row, 4),
        napHours: _double(row, 5),
        tags: _list(row, 6),
      ).toMap(),
    ),
    'nap_entries.csv': (row) => _add(
      'nap_entries',
      NapEntry(date: _day(row, 1)!, startTime: _dateTime(row, 2)!, durationHours: _double(row, 3)!, tags: _list(row, 4)).toMap(),
    ),
    'meal_entries.csv': (row) => _add(
      'meal_entries',
      MealEntry(
        date: _day(row, 1)!,
        time: _dateTime(row, 2)!,
        name: _text(row, 3)!,
        quantity: _int(row, 4) ?? 1,
        price: _double(row, 5),
        calories: _int(row, 6),
        tags: _list(row, 7),
        notes: _text(row, 8),
        foodSource: _text(row, 9),
        foodItemId: _foodIds[_text(row, 10)?.toLowerCase()],
        currency: _text(row, 11) ?? 'SGD',
        rawText: _text(row, 12),
        timeKnown: (_int(row, 13) ?? 1) != 0,
      ).toMap(),
    ),
    'mood_entries.csv': (row) => _add(
      'mood_entries',
      MoodEntry(
        date: _day(row, 1)!,
        timestamp: _dateTime(row, 2)!,
        moodLevel: _int(row, 3)!,
        emoji: _text(row, 4) ?? '',
        notes: _text(row, 5),
      ).toMap(),
    ),
    'exercise_entries.csv': (row) => _add(
      'exercise_entries',
      ExerciseEntry(
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
        exerciseItemId: _exerciseIds[_text(row, 18)?.toLowerCase()],
        rawText: _text(row, 19),
      ).toMap(),
    ),
    'task_entries.csv': (row) => _add(
      'task_entries',
      TaskEntry(
        date: _day(row, 1)!,
        timestamp: _dateTime(row, 2)!,
        taskType: _enum(TaskType.values, _text(row, 3))!,
        notes: _text(row, 4),
      ).toMap(),
    ),
    'activity_entries.csv': (row) => _add(
      'activity_entries',
      ActivityEntry(
        date: _day(row, 1)!,
        timestamp: _dateTime(row, 2)!,
        // Prefer the tag name column; older exports only have the tag ID.
        tagId: _tagId(_text(row, 5) ?? _exportedTagNames[_int(row, 3)]),
        notes: _text(row, 4),
        severity: _int(row, 6),
      ).toMap(),
    ),
    'journal_entries.csv': (row) async {
      final names = _list(row, 7).toSet();
      final tagIds = {for (final name in names) _tagId(name)};
      final entry = JournalEntry(
        date: _day(row, 1)!,
        time: _dateTime(row, 2),
        text: _text(row, 3) ?? '',
        mood: _int(row, 4),
        source: _text(row, 5) ?? 'app',
        createdAt: _dateTime(row, 6),
      );
      final map = entry.toMap()..remove('id');
      map['date'] = dayOf(entry.date).toIso8601String();
      if (!_journalKeys.add(_journalKey(map, names))) return false;
      final id = await txn.insert('journal_entries', map);
      for (final tagId in tagIds) {
        await txn.insert('journal_entry_tags', {'entry_id': id, 'tag_id': tagId});
      }
      return true;
    },
    'day_checkins.csv': (row) => _add(
      'day_checkins',
      DayCheckin(
        date: _day(row, 0)!,
        energy: _int(row, 1),
        stress: _int(row, 2),
        focus: _int(row, 3),
        plantOverride: _text(row, 4),
      ).toMap(),
    ),
    'health_metrics.csv': (row) => _add(
      'health_metrics',
      HealthMetric(date: _day(row, 0)!, metric: _text(row, 1)!, value: _double(row, 2)!, source: _text(row, 3)!).toMap(),
    ),
    'health_workouts.csv': (row) => _add(
      'health_workouts',
      HealthWorkout(
        start: _dateTime(row, 0)!,
        type: _text(row, 1)!,
        durationMin: _double(row, 2),
        distanceKm: _double(row, 3),
        kcal: _double(row, 4),
        avgHr: _double(row, 5),
        maxHr: _double(row, 6),
        source: _text(row, 7)!,
      ).toMap(),
    ),
    'daylio_raw.csv': (row) => _add(
      'daylio_raw',
      DaylioRawEntry(
        date: _day(row, 0)!,
        loggedTime: _text(row, 1)!,
        mood: _int(row, 2),
        activities: _text(row, 3) ?? '',
        note: _text(row, 4) ?? '',
      ).toMap(),
    ),
  };
}

// ---- Cell parsing helpers; an empty cell is null. ----

String? _text(List<dynamic> row, int i) {
  if (i >= row.length) return null;
  final value = row[i].toString();
  return value.isEmpty ? null : value;
}

int? _int(List<dynamic> row, int i) {
  final text = _text(row, i);
  return text == null ? null : int.parse(text);
}

double? _double(List<dynamic> row, int i) {
  final text = _text(row, i);
  return text == null ? null : double.parse(text);
}

DateTime? _dateTime(List<dynamic> row, int i) {
  final text = _text(row, i);
  return text == null ? null : DateTime.parse(text);
}

DateTime? _day(List<dynamic> row, int i) {
  final value = _dateTime(row, i);
  return value == null ? null : dayOf(value);
}

/// Seconds, or the `H:MM:SS.ffffff` form written by older exports.
Duration? _duration(List<dynamic> row, int i) {
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

List<String> _list(List<dynamic> row, int i) => _text(row, i)?.split(';') ?? [];

/// Accepts `name` and the older `EnumType.name` form.
T? _enum<T extends Enum>(List<T> values, String? text) {
  if (text == null) return null;
  final name = text.split('.').last;
  return values.firstWhere((v) => v.name == name);
}
