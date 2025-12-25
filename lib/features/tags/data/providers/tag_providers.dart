import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/models/activity_entry.dart';
import '../models/tag.dart';

/// All tags provider
final allTagsProvider = FutureProvider<List<Tag>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllTags();
});

/// All tag categories provider
final allTagCategoriesProvider = FutureProvider<List<TagCategory>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllTagCategories();
});

/// Tags by category provider
final tagsByCategoryProvider = FutureProvider.family<List<Tag>, String>((ref, category) async {
  final db = ref.watch(databaseProvider);
  return db.getTagsByCategory(category);
});

/// Activity entries provider for a specific date
final activityEntriesProvider = FutureProvider.family<List<ActivityEntry>, DateTime>((ref, date) async {
  final db = ref.watch(databaseProvider);
  return db.getActivityEntriesByDate(date);
});
