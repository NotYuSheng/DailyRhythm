import 'package:daily_rhythm/features/health/data/health_sync_service.dart';
import 'package:daily_rhythm/features/health/data/models/health_metric.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/services/database/repositories/health_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';
import 'garmin_export_reader_test.dart' show makeExport;

class FakeStore implements HealthStore {
  FakeStore({this.grant = true});

  final bool grant;
  int accessRequests = 0;

  @override
  String get source => HealthSource.healthConnect;

  @override
  Future<bool> available() async => true;

  @override
  Future<bool> requestAccess() async {
    accessRequests++;
    return grant;
  }

  @override
  Future<int?> steps(DateTime from, DateTime to) async => from.day == 8 ? 9000 : null;

  @override
  Future<List<HealthSample>> samples(DateTime from, DateTime to) async => [
        HealthSample.sleep(DateTime(2026, 3, 7, 23, 30), DateTime(2026, 3, 8, 3)),
        HealthSample.sleep(DateTime(2026, 3, 8, 3, 20), DateTime(2026, 3, 8, 7)),
        HealthSample.restingHr(DateTime(2026, 3, 8, 6), 52),
        HealthSample.restingHr(DateTime(2026, 3, 8, 20), 56),
        HealthSample.workout(DateTime(2026, 3, 8, 18, 0, 30), DateTime(2026, 3, 8, 18, 30), type: 'running', kcal: 300, distanceKm: 5.123),
      ];
}

void main() {
  late DatabaseService db;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await openTestDatabase();
  });
  tearDown(closeTestDatabase);

  test('daily metrics: steps, sleep on the day it ended, average resting heart rate', () async {
    final store = FakeStore();
    final metrics = HealthSyncService.dailyMetrics({DateTime(2026, 3, 8): 9000}, await store.samples(DateTime(2026), DateTime(2027)), 'health_connect');
    final byName = {for (final m in metrics) m.metric: (m.date, m.value)};
    expect(byName['steps'], (DateTime(2026, 3, 8), 9000.0));
    expect(byName['sleep_minutes'], (DateTime(2026, 3, 8), 430.0));
    expect(byName['resting_hr'], (DateTime(2026, 3, 8), 54.0));
    final w = HealthSyncService.workouts(await store.samples(DateTime(2026), DateTime(2027)), 'health_connect').single;
    expect((w.start, w.durationMin, w.distanceKm, w.kcal), (DateTime(2026, 3, 8, 18), 29.5, 5.12, 300.0));
  });

  test('access is asked for only when sync is turned on', () async {
    final store = FakeStore();
    final service = HealthSyncService(db, store);
    expect(store.accessRequests, 0);
    expect(await service.setEnabled(true), (true, null));
    expect(await HealthSyncService.isEnabled(), isTrue);
    expect(store.accessRequests, 1);
    await service.setEnabled(false);
    expect((store.accessRequests, await HealthSyncService.isEnabled()), (1, false));

    final denied = HealthSyncService(db, FakeStore(grant: false));
    expect((await denied.setEnabled(true)).$1, isFalse);
    expect(await HealthSyncService.isEnabled(), isFalse);
  });

  test('syncing twice changes nothing the second time', () async {
    final service = HealthSyncService(db, FakeStore());
    await service.sync(now: DateTime(2026, 3, 10));
    final rows = await (await db.database).query('health_metrics');
    final workouts = await (await db.database).query('health_workouts');
    await service.sync(now: DateTime(2026, 3, 10, 12));
    expect(await (await db.database).query('health_metrics'), hasLength(rows.length));
    expect(await (await db.database).query('health_workouts'), hasLength(workouts.length));
    expect(await HealthSyncService.lastSync(), DateTime(2026, 3, 10, 12));
  });

  test('a Garmin export wins over Health Connect on the same day', () async {
    final service = HealthSyncService(db, FakeStore());
    await service.sync(now: DateTime(2026, 3, 10));
    expect(await service.importGarmin(makeExport()), (1, 1));
    final day = await HealthRepository(db).forDay(DateTime(2026, 3, 8));
    expect((day['steps']!.value, day['steps']!.source), (7117, HealthSource.garminExport));
    expect((day['sleep_minutes']!.value, day['sleep_minutes']!.source), (407, HealthSource.garminExport));
    // Re-importing the same export adds nothing.
    final count = (await (await db.database).query('health_metrics')).length;
    await service.importGarmin(makeExport());
    expect(await (await db.database).query('health_metrics'), hasLength(count));
  });
}
