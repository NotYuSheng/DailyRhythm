import 'package:daily_rhythm/features/journal/data/models/journal_entry.dart';
import 'package:daily_rhythm/features/tags/data/models/tag.dart';
import 'package:daily_rhythm/shared/models/activity_entry.dart';
import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:daily_rhythm/shared/services/database/repositories/journal_repository.dart';
import 'package:daily_rhythm/shared/services/database/schema_v17.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late DatabaseService db;
  setUp(() async => db = await openTestDatabase());
  tearDown(closeTestDatabase);

  test('a new install has Appointments and no Intense Exercise', () async {
    final tags = {for (final t in await db.getAllTags()) t.name: t};
    expect(tags.containsKey('Intense Exercise'), isFalse);
    expect(tags['Haircut']!.category, SchemaV17.group);
    expect([for (final c in await db.getAllTagCategories()) c.name], contains(SchemaV17.group));
  });

  test('an upgrade deletes the retired tags and their days, and moves appointments', () async {
    final day = DateTime(2026, 11, 9);
    final nap = await db.createTag(Tag(name: 'Nap', emoji: 'tag', category: 'Activity'));
    final early = await db.createTag(Tag(name: 'Woke Up Early', emoji: 'tag', category: 'Activity'));
    final dentist = await db.createTag(Tag(name: 'Dentist', emoji: 'tag', category: 'Activity'));
    await db.createTag(Tag(name: 'Cab', emoji: 'tag', category: 'Activity'));
    await db.createTag(Tag(name: 'Nap pod', emoji: 'tag', category: 'Food', kind: TagKind.foodSource));
    for (final id in [nap, early, dentist]) {
      await db.createActivityEntry(ActivityEntry(date: day, timestamp: day, tagId: id));
    }
    await JournalRepository(db).save(JournalEntry(date: day, text: 'Long nap', tagIds: [nap, dentist]));

    await SchemaV17.apply(await db.database);
    await SchemaV17.apply(await db.database);

    final tags = {for (final t in await db.getAllTags()) t.name: t.category};
    expect(tags.keys, isNot(contains('Nap')));
    expect(tags.keys, isNot(contains('Woke Up Early')));
    expect((tags['Dentist'], tags['Cab'], tags['Nap pod']), (SchemaV17.group, SchemaV17.group, 'Food'), reason: 'only activity tags change');
    expect([for (final e in await db.getActivityEntriesByDate(day)) e.tagId], [dentist], reason: 'their days go with them');
    expect((await JournalRepository(db).forDay(day)).single.tagIds, [dentist], reason: 'the moment stays, without the deleted tag');
    expect([for (final c in await db.getAllTagCategories()) if (c.name == SchemaV17.group) c].length, 1, reason: 'safe to run twice');
  });
}
