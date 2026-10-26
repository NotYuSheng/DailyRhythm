import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/spending_entry.dart';
import '../../../shared/services/database/database_provider.dart';
import '../../../shared/services/database/repositories/spending_repository.dart';

/// Events and gifts on a day.
final spendingProvider = FutureProvider.family<List<SpendingEntry>, DateTime>((ref, day) {
  return SpendingRepository(ref.watch(databaseProvider)).forDay(day);
});
