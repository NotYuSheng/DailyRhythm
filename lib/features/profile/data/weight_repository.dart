import '../../../shared/services/database/database_service.dart';
import '../../../shared/services/database/repositories/health_repository.dart';
import '../../health/data/models/health_metric.dart';

/// Body weight over time, as the `weight_kg` health metric (one a day).
class WeightRepository {
  WeightRepository([DatabaseService? db]) : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  static const metric = 'weight_kg';

  Future<void> log(DateTime day, double kg) =>
      HealthRepository(_db).saveMetrics([HealthMetric(date: day, metric: metric, value: kg, source: HealthSource.manual)]);

  Future<List<HealthMetric>> inRange(DateTime start, DateTime end) => HealthRepository(_db).series(metric, start, end);

  /// The most recent weight, from any source.
  Future<HealthMetric?> latest() async {
    final db = await _db.database;
    final rows = await db.query('health_metrics', where: 'metric = ?', whereArgs: [metric], orderBy: 'date DESC', limit: 1);
    return rows.isEmpty ? null : HealthMetric.fromMap(rows.first);
  }
}
