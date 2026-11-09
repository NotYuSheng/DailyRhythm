import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/models/activity_entry.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../../../tags/data/models/tag.dart';
import '../../../tags/data/providers/tag_providers.dart';
import '../../../tags/presentation/screens/tags_screen.dart';
import '../../../tags/presentation/tag_icons.dart';
import '../garden_style.dart';

/// Tags what a day included. Like the other add screens, nothing is saved
/// until Save; going back leaves the day as it was.
class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key, required this.day});

  final DateTime day;

  static const groups = [
    (TagKind.activity, 'Activities'),
    (TagKind.foodSource, 'Food from'),
    (TagKind.symptom, 'Symptoms'),
  ];

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  /// The tags picked on screen; null until the day's saved tags load.
  Set<int>? _picked;
  bool _saving = false;

  Future<void> _save(Set<int> picked) async {
    if (_saving) return;
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final navigator = Navigator.of(context);
    // Read again: what was on screen may be out of date.
    final saved = await db.getActivityEntriesByDate(widget.day);
    for (final e in saved) {
      if (!picked.contains(e.tagId)) await db.deleteActivityEntry(e.id!);
    }
    final had = {for (final e in saved) e.tagId};
    for (final id in picked.difference(had)) {
      await db.createActivityEntry(ActivityEntry(date: widget.day, timestamp: DateTime.now(), tagId: id));
    }
    ref.invalidate(activityEntriesProvider(widget.day));
    if (mounted) navigator.pop();
  }

  /// Tags by group (Chores, Hobby, Work…), groups by name; one unnamed
  /// group when all share one.
  static List<(String?, List<Tag>)> _byGroup(Iterable<Tag> tags) {
    final groups = <String, List<Tag>>{};
    for (final t in tags) {
      groups.putIfAbsent(t.category, () => []).add(t);
    }
    if (groups.length <= 1) return [(null, tags.toList())];
    final names = groups.keys.toList()..sort();
    return [for (final n in names) (n, groups[n]!)];
  }

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    final tags = ref.watch(allTagsProvider).value ?? const <Tag>[];
    final saved = ref.watch(activityEntriesProvider(widget.day)).value;
    final picked = _picked ??= saved == null ? null : {for (final e in saved) e.tagId};

    return Scaffold(
      appBar: AppBar(
        title: const Text('What today included'),
        actions: [
          TextButton(onPressed: picked == null || _saving ? null : () => _save(picked), child: const Text('Save')),
        ],
      ),
      body: picked == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                for (final (kind, title) in ActivitiesScreen.groups)
                  if (tags.any((t) => t.kind == kind)) ...[
                    const SizedBox(height: 14),
                    Text(title, style: nunito(16, FontWeight.w900, colors.ink)),
                    // A kind's tags by their group (Chores, Work, Hobby…) when it has several.
                    for (final (group, groupTags) in _byGroup(tags.where((t) => t.kind == kind))) ...[
                      if (group != null) ...[
                        const SizedBox(height: 8),
                        Text(group, style: nunito(13, FontWeight.w800, colors.leaf)),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in groupTags)
                            FilterChip(
                              avatar: Icon(tagIcon(tag), size: 18),
                              // The fill shows it's picked; the icon stays.
                              showCheckmark: false,
                              label: Text(tag.name),
                              selected: picked.contains(tag.id),
                              onSelected: (on) => setState(() => on ? picked.add(tag.id!) : picked.remove(tag.id)),
                            ),
                        ],
                      ),
                    ],
                  ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: colors.accent),
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const TagsScreen()));
                      ref.invalidate(allTagsProvider);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text('Edit tags', style: nunito(14, FontWeight.w800, colors.accent)),
                  ),
                ),
              ],
            ),
    );
  }
}
