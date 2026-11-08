import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:daily_rhythm/features/health/data/garmin_export_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// The same minimal export as tools/daylio_migration/tests/test_garmin.py.
List<int> makeExport() {
  final files = {
    'DI_CONNECT/DI-Connect-Aggregator/UDSFile_2026-03-07_2026-03-09.json': [
      {
        'calendarDate': '2026-03-08',
        'totalSteps': 7117,
        'restingHeartRate': 54,
        'allDayStress': {
          'aggregatorList': [
            {'type': 'ASLEEP', 'averageStressLevel': 11},
            {'type': 'TOTAL', 'averageStressLevel': 31, 'maxStressLevel': 92},
          ],
        },
        'bodyBattery': {
          'chargedValue': 77,
          'drainedValue': 39,
          'bodyBatteryStatList': [
            {'bodyBatteryStatType': 'HIGHEST', 'statsValue': 86},
            {'bodyBatteryStatType': 'LOWEST', 'statsValue': 9},
          ],
        },
      },
      {
        'calendarDate': '2026-03-09',
        'totalSteps': -1,
        'allDayStress': {
          'aggregatorList': [
            {'type': 'TOTAL', 'averageStressLevel': -2},
          ],
        },
      },
    ],
    'DI_CONNECT/DI-Connect-Wellness/2026-03-07_2026-03-09_1_sleepData.json': [
      {
        'calendarDate': '2026-03-08',
        'deepSleepSeconds': 5160,
        'lightSleepSeconds': 16260,
        'remSleepSeconds': 3000,
        'awakeSleepSeconds': 600,
        'sleepScores': {'overallScore': 79},
      },
      {'calendarDate': '2026-03-09', 'retro': false},
    ],
    'DI_CONNECT/DI-Connect-Wellness/2026-03-07_2026-03-09_1_healthStatusData.json': [
      {
        'calendarDate': '2026-03-08',
        'metrics': [
          {'type': 'HRV', 'value': 59.0, 'baselineLowerLimit': 43.0, 'baselineUpperLimit': 65.0},
          {'type': 'SPO2', 'value': null},
        ],
      },
    ],
    'DI_CONNECT/DI-Connect-Fitness/me_1_summarizedActivities.json': [
      {
        'summarizedActivitiesExport': [
          {
            'activityType': 'running',
            'startTimeLocal': 1772991480000.0,
            'duration': 1662000.0,
            'distance': 362000.0,
            'calories': 1029.3,
            'avgHr': 162.0,
          },
        ],
      },
    ],
    'DI_CONNECT/DI-Connect-User/user_profile.json': {'email': 'someone@example.com'},
  };
  final archive = Archive();
  for (final MapEntry(:key, :value) in files.entries) {
    archive.addFile(ArchiveFile.bytes(key, utf8.encode(jsonEncode(value))));
  }
  return ZipEncoder().encode(archive);
}

void main() {
  test('reads daily metrics, sleep, HRV and workouts like the migration tool', () {
    final result = GarminExportReader.readZip(makeExport());
    final m = {for (final x in result.metrics) if (x.date == DateTime(2026, 3, 8)) x.metric: x.value};

    expect((m['steps'], m['resting_hr'], m['stress_avg'], m['stress_max']), (7117, 54, 31, 92));
    expect((m['body_battery_high'], m['body_battery_low'], m['body_battery_charged']), (86, 9, 77));
    expect((m['sleep_minutes'], m['sleep_deep_minutes'], m['sleep_score']), (407, 86, 79));
    expect((m['hrv'], m['hrv_baseline_low'], m['hrv_baseline_high']), (59, 43, 65));
    expect(m.containsKey('spo2'), isFalse);
    expect({for (final x in result.metrics) x.source}, {'garmin_export'});

    final w = result.workouts.single;
    expect((w.type, w.start, w.durationMin, w.distanceKm, w.kcal, w.avgHr, w.maxHr),
        ('running', DateTime(2026, 3, 8, 17, 38), 27.7, 3.62, 246.0, 162.0, null));
  });

  test('skips no-data values and unmeasured nights', () {
    final result = GarminExportReader.readZip(makeExport());
    expect(result.metrics.where((m) => m.date == DateTime(2026, 3, 9)), isEmpty);
    expect(result.days, 1);
  });

  test('a zip without Garmin files is rejected', () {
    final archive = Archive()..addFile(ArchiveFile.bytes('notes.txt', utf8.encode('hello')));
    expect(() => GarminExportReader.readZip(ZipEncoder().encode(archive)), throwsFormatException);
  });
}
