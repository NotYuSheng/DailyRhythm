import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_service.dart';

/// Shared database provider used across all features
final databaseProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});
