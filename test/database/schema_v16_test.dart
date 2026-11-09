import 'package:daily_rhythm/features/tags/data/models/tag.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/services/database/schema_v16.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late DatabaseService db;
  setUp(() async => db = await openTestDatabase());
  tearDown(closeTestDatabase);

  test('chore tags sit in their own group', () async {
    final tags = {for (final t in await db.getAllTags()) t.name: t};
    expect(tags['Change Bedsheets']!.category, SchemaV16.group);
    expect([for (final c in await db.getAllTagCategories()) c.name], contains(SchemaV16.group));
  });

  test('an upgrade moves chore-like activities, not other kinds or other names', () async {
    await db.createTag(Tag(name: 'Laundry', emoji: 'tag', category: 'General'));
    await db.createTag(Tag(name: 'Deep clean', emoji: 'tag', category: 'Hobby'));
    await db.createTag(Tag(name: 'Clean eating', emoji: 'tag', category: 'Food', kind: TagKind.foodSource));
    await db.createTag(Tag(name: 'Gaming', emoji: 'tag', category: 'Hobby'));
    await SchemaV16.apply(await db.database);
    await SchemaV16.apply(await db.database);
    final tags = {for (final t in await db.getAllTags()) t.name: t.category};
    expect((tags['Laundry'], tags['Deep clean'], tags['Clean eating'], tags['Gaming']), (SchemaV16.group, SchemaV16.group, 'Food', 'Hobby'));
    expect([for (final c in await db.getAllTagCategories()) if (c.name == SchemaV16.group) c].length, 1, reason: 'safe to run twice');
  });
}
