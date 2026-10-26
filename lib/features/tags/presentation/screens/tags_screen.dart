import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/services/database/database_service.dart';
import '../../../garden/data/garden_providers.dart';
import '../../../garden/presentation/garden_style.dart';
import '../../data/models/tag.dart';
import '../../data/providers/tag_providers.dart';

/// The kinds of tag, in the order they are shown.
const tagKinds = [
  (TagKind.activity, 'Activities', 'What you did'),
  (TagKind.foodSource, 'Food from', 'Where meals came from'),
  (TagKind.symptom, 'Symptoms', 'How your body felt'),
];

/// Refreshes everything that shows tags after one changes. Takes the
/// container, read before any await, so it works after a sheet closes.
void _invalidateTags(ProviderContainer container) {
  for (final provider in [allTagsProvider, allTagCategoriesProvider, tagUseCountsProvider]) {
    container.invalidate(provider);
  }
  container.invalidate(tagsByCategoryProvider);
  container.invalidate(activityEntriesProvider);
  container.invalidate(momentsProvider);
  container.invalidate(gardenDayProvider);
  container.invalidate(gardenMonthProvider);
}

/// A tag's kind, with anything unrecognised (an odd value from an import)
/// shown as an activity so it can still be edited.
String kindOf(Tag tag) => tagKinds.any((k) => k.$1 == tag.kind) ? tag.kind : TagKind.activity;

/// By the user's order where set, then by name.
int _byOrder(int? a, int? b, String nameA, String nameB) =>
    a != b ? (a ?? 1 << 30).compareTo(b ?? 1 << 30) : nameA.toLowerCase().compareTo(nameB.toLowerCase());

/// Tags grouped by kind, as pills. Tap one to rename it, change its kind
/// or group, merge it into another, or delete it.
class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);
    final tags = ref.watch(allTagsProvider);
    final uses = ref.watch(tagUseCountsProvider).value ?? const <int, int>{};

    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(title: const Text('Tags'), backgroundColor: colors.ground),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTagSheet(context),
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        icon: const Icon(Icons.add),
        label: const Text('New tag'),
      ),
      body: tags.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Couldn’t load tags: $e')),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
          children: [
            Text(
              'Tap a tag to rename it, change its kind, merge it into another or delete it.',
              style: nunito(14, FontWeight.w600, colors.muted),
            ),
            for (final (kind, title, subtitle) in tagKinds) ...[
              const SizedBox(height: 20),
              Semantics(header: true, child: Text(title, style: nunito(20, FontWeight.w900, colors.ink))),
              Text(subtitle, style: nunito(13, FontWeight.w600, colors.muted)),
              const SizedBox(height: 8),
              _KindCard(tags: [for (final t in list) if (kindOf(t) == kind) t], kind: kind, uses: uses, colors: colors),
            ],
          ],
        ),
      ),
    );
  }
}

class _KindCard extends ConsumerWidget {
  const _KindCard({required this.tags, required this.kind, required this.uses, required this.colors});

  final List<Tag> tags;
  final String kind;
  final Map<int, int> uses;
  final GardenColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byCategory = <String, List<Tag>>{};
    for (final t in tags) {
      byCategory.putIfAbsent(t.category, () => []).add(t);
    }
    final order = {for (final c in ref.watch(allTagCategoriesProvider).value ?? const <TagCategory>[]) c.name: c.sortOrder};
    final categories = byCategory.keys.toList()..sort((a, b) => _byOrder(order[a], order[b], a, b));
    // Groups are optional: only shown when a kind has more than one.
    final showGroups = categories.length > 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(26)),
      child: tags.isEmpty
          ? Text('None yet', style: nunito(14, FontWeight.w600, colors.muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, category) in categories.indexed) ...[
                  if (showGroups) ...[
                    if (i > 0) const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _renameCategory(context, ref, category),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 32),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(category, style: nunito(13, FontWeight.w800, colors.leaf)),
                            const SizedBox(width: 4),
                            Icon(Icons.edit_outlined, size: 14, color: colors.leaf, semanticLabel: 'Rename group'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in byCategory[category]!..sort((a, b) => _byOrder(a.sortOrder, b.sortOrder, a.name, b.name)))
                        _TagPill(tag: tag, uses: uses[tag.id] ?? 0, colors: colors),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  /// Renames a group for this kind's tags only; renaming to a group that
  /// already exists joins it.
  Future<void> _renameCategory(BuildContext context, WidgetRef ref, String name) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: name);
    final renamed = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename group'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Rename')),
        ],
      ),
    );
    controller.dispose();
    if (renamed == null || renamed.isEmpty || renamed == name) return;
    try {
      await container.read(databaseProvider).moveTagsToGroup([for (final t in tags) if (t.category == name) t.id!], renamed);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Couldn’t rename the group: $e')));
    }
    _invalidateTags(container);
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag, required this.uses, required this.colors});

  final Tag tag;
  final int uses;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${tag.name}, used $uses ${uses == 1 ? 'time' : 'times'}',
      excludeSemantics: true,
      child: Material(
        color: colors.ground,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => showTagSheet(context, tag: tag),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tag.name, style: nunito(14, FontWeight.w800, colors.ink)),
                  if (uses > 0) ...[
                    const SizedBox(width: 6),
                    Text('$uses', style: nunito(12, FontWeight.w700, colors.muted)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the editor for [tag], or for a new tag when null.
Future<void> showTagSheet(BuildContext context, {Tag? tag}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => TagSheet(tag: tag),
  );
}

class TagSheet extends ConsumerStatefulWidget {
  const TagSheet({super.key, this.tag});

  final Tag? tag;

  @override
  ConsumerState<TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends ConsumerState<TagSheet> {
  late final _name = TextEditingController(text: widget.tag?.name ?? '');
  late final _group = TextEditingController(text: widget.tag?.category ?? 'General');
  final _groupFocus = FocusNode();
  late String _kind = widget.tag?.kind ?? TagKind.activity;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _group.dispose();
    _groupFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final group = _group.text.trim().isEmpty ? 'General' : _group.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the tag a name');
      return;
    }
    final clash = (ref.read(allTagsProvider).value ?? const <Tag>[])
        .where((t) => t.name.toLowerCase() == name.toLowerCase() && t.id != widget.tag?.id);
    if (clash.isNotEmpty) {
      setState(() => _error = 'There’s already a tag called ${clash.first.name}. Merge into it instead?');
      return;
    }
    await _run((db) async {
      final tag = widget.tag;
      if (tag == null) {
        await db.createTag(Tag(name: name, emoji: 'tag', category: group, kind: _kind));
        await db.moveTagsToGroup(const [], group); // makes sure the group exists
      } else {
        await db.updateTag(tag.copyWith(name: name, kind: _kind));
        await db.moveTagsToGroup([tag.id!], group);
      }
    });
  }

  /// Runs one change with the sheet disabled, refreshes, and closes;
  /// shows the error instead if it fails.
  Future<void> _run(Future<void> Function(DatabaseService db) change) async {
    if (_busy) return;
    setState(() => _busy = true);
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context);
    try {
      await change(container.read(databaseProvider));
    } catch (e) {
      if (mounted) setState(() => _error = 'Couldn’t save: $e');
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _invalidateTags(container);
    if (mounted) navigator.pop();
  }

  Future<void> _merge(Tag tag, int uses) async {
    final others = [for (final t in ref.read(allTagsProvider).value ?? const <Tag>[]) if (t.id != tag.id) t]
      // Same kind first, then by name.
      ..sort((a, b) => a.kind == b.kind
          ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
          : (a.kind == tag.kind ? -1 : b.kind == tag.kind ? 1 : 0));
    final into = await showDialog<Tag>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Merge ${tag.name} into…'),
        children: [
          SizedBox(
            width: double.maxFinite,
            height: 360,
            child: ListView(
              children: [
                for (final t in others)
                  ListTile(title: Text(t.name), subtitle: Text(t.category), onTap: () => Navigator.pop(context, t)),
              ],
            ),
          ),
        ],
      ),
    );
    if (into == null || !mounted) return;
    final ok = await _confirm(
      'Merge ${tag.name} into ${into.name}?',
      'Its $uses ${uses == 1 ? 'use moves' : 'uses move'} to ${into.name} (a day that has both keeps one), and ${tag.name} is removed.',
      'Merge',
    );
    if (!ok) return;
    await _run((db) => db.mergeTags(tag.id!, into.id!));
  }

  Future<void> _delete(Tag tag, int uses) async {
    final ok = await _confirm(
      'Delete ${tag.name}?',
      uses == 0 ? 'It isn’t used anywhere.' : 'It’s removed from the $uses ${uses == 1 ? 'day or moment' : 'days and moments'} that use it.',
      'Delete',
    );
    if (!ok) return;
    await _run((db) => db.deleteTag(tag.id!));
  }

  Future<bool> _confirm(String title, String message, String action) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    final tag = widget.tag;
    final uses = tag == null ? 0 : ref.watch(tagUseCountsProvider).value?[tag.id] ?? 0;
    // Groups in use, so a mistyped one goes away once nothing uses it.
    final groups = {for (final t in ref.watch(allTagsProvider).value ?? const <Tag>[]) t.category}.toList()..sort();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tag == null ? 'New tag' : tag.name, style: nunito(22, FontWeight.w900, colors.ink)),
            if (tag != null)
              Text('Used $uses ${uses == 1 ? 'time' : 'times'}', style: nunito(14, FontWeight.w600, colors.muted)),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              autofocus: tag == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Name', errorText: _error, errorMaxLines: 3),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 14),
            Text('Kind', style: nunito(15, FontWeight.w800, colors.leaf)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final (kind, title, _) in tagKinds)
                  ButtonSegment(value: kind, label: FittedBox(fit: BoxFit.scaleDown, child: Text(title))),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 14),
            RawAutocomplete<String>(
              textEditingController: _group,
              focusNode: _groupFocus,
              optionsBuilder: (value) => groups.where((g) => g.toLowerCase().contains(value.text.toLowerCase())),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220, maxWidth: 320),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [for (final o in options) ListTile(title: Text(o), onTap: () => onSelected(o))],
                    ),
                  ),
                ),
              ),
              fieldViewBuilder: (context, controller, focus, onSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focus,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Group (optional)', helperText: 'Groups sort tags within a kind'),
                );
              },
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: colors.accent,
                foregroundColor: colors.onAccent,
              ),
              child: Text(tag == null ? 'Add tag' : 'Save', style: nunito(15, FontWeight.w900, colors.onAccent)),
            ),
            if (tag != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(minimumSize: const Size(0, 48), foregroundColor: colors.leaf),
                      onPressed: _busy ? null : () => _merge(tag, uses),
                      icon: const Icon(Icons.merge_type),
                      label: const Text('Merge into…'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(minimumSize: const Size(0, 48), foregroundColor: Theme.of(context).colorScheme.error),
                      onPressed: _busy ? null : () => _delete(tag, uses),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
