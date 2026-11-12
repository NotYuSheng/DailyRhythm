import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/services/database/database_service.dart';
import '../../../garden/data/garden_providers.dart';
import '../../../garden/presentation/garden_style.dart';
import '../../../ai/data/ai_providers.dart';
import '../../../meals/data/services/food_source_tags.dart';
import '../tag_icons.dart';
import 'tag_calendar_screen.dart';
import '../../data/models/tag.dart';
import '../../data/providers/tag_providers.dart';

/// The kinds of tag, in the order they are shown.
const tagKinds = [
  (TagKind.activity, 'Activities', 'What you did'),
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
String kindOf(Tag tag) => tag.knownKind;

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
              'Tap a tag to rename it, change its kind, group or icon, merge it or delete it. Tap a group’s name to rename, move or delete it.',
              style: nunito(14, FontWeight.w600, colors.muted),
            ),
            if (list.any((t) => t.kind == TagKind.foodSource)) ...[
              const SizedBox(height: 20),
              _OldFoodSourceCard(tags: [for (final t in list) if (t.kind == TagKind.foodSource) t], colors: colors),
            ],
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

/// The old day-level "Food from" tags, now that meals record their source:
/// moves them onto meals (with the AI for unclear days) and deletes them.
class _OldFoodSourceCard extends ConsumerStatefulWidget {
  const _OldFoodSourceCard({required this.tags, required this.colors});

  final List<Tag> tags;
  final GardenColors colors;

  @override
  ConsumerState<_OldFoodSourceCard> createState() => _OldFoodSourceCardState();
}

class _OldFoodSourceCardState extends ConsumerState<_OldFoodSourceCard> {
  String? _progress;

  Future<void> _move() async {
    final container = ProviderScope.containerOf(context);
    final messenger = ScaffoldMessenger.of(context);
    // The settings load on first use: wait for them, or a set-up assistant
    // reads as missing.
    await ref.read(aiSettingsProvider.future);
    if (!mounted) return;
    final ai = ref.read(aiClientProvider);
    if (ai == null) {
      // Without the AI most days can't be matched, and the tags would be
      // lost, so nothing moves until it is set up.
      messenger.showSnackBar(const SnackBar(content: Text('Set up the AI assistant in Settings first. Nothing has changed.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move onto meals?'),
        content: const Text('Days with one tag and one meal get that meal’s source. For the others, the AI assistant matches tags to meals; '
            'this sends the dates and meal names to your AI provider, and can take a while. Keep this screen open. '
            'The tags are then deleted, with Supplement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Move')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _progress = 'Starting…');
    try {
      final result = await FoodSourceTags(ref.read(databaseProvider)).run(
        ai: ai,
        progress: (done, total) {
          if (mounted) setState(() => _progress = 'Matching days $done of $total…');
        },
      );
      _invalidateTags(container);
      messenger.showSnackBar(SnackBar(
        content: Text('Set where ${result.mealsSet} ${result.mealsSet == 1 ? 'meal' : 'meals'} came from'
            '${result.daysSkipped > 0 ? '. ${result.daysSkipped} ${result.daysSkipped == 1 ? 'day had' : 'days had'} no meal to match' : ''}.'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Nothing changed: $e')));
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Old “Food from” tags', style: nunito(17, FontWeight.w900, colors.ink)),
          const SizedBox(height: 4),
          Text(
            'Meals now say where they came from. ${widget.tags.map((t) => t.name).join(', ')} '
            'can move onto the meals of the days they were on, then go.',
            style: nunito(13, FontWeight.w600, colors.muted),
          ),
          const SizedBox(height: 10),
          if (_progress case final p?)
            Row(children: [
              const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Flexible(child: Text(p, style: nunito(13, FontWeight.w700, colors.muted))),
            ])
          else
            FilledButton.tonalIcon(onPressed: _move, icon: const Icon(Icons.restaurant_outlined), label: const Text('Move onto meals')),
        ],
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
    // Group headings always show, so every group can be managed.
    const showGroups = true;

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
                      onTap: () => _groupMenu(context, ref, category, categories),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 32),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(category, style: nunito(13, FontWeight.w800, colors.leaf)),
                            const SizedBox(width: 4),
                            Icon(Icons.more_horiz, size: 16, color: colors.leaf, semanticLabel: 'Group options'),
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

  /// A group's options: rename, move up or down, or delete (its tags move
  /// to the default group).
  Future<void> _groupMenu(BuildContext context, WidgetRef ref, String group, List<String> shown) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final at = shown.indexOf(group);
    final count = tags.where((t) => t.category == group).length;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(group, style: nunito(20, FontWeight.w900, colors.ink)),
            ),
            ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Rename group'), onTap: () => Navigator.pop(context, 'rename')),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: const Text('Move up'),
              enabled: at > 0,
              onTap: () => Navigator.pop(context, 'up'),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: const Text('Move down'),
              enabled: at < shown.length - 1,
              onTap: () => Navigator.pop(context, 'down'),
            ),
            if (group != DatabaseService.defaultGroup)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                title: Text('Delete group', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                subtitle: Text('Its $count ${count == 1 ? 'tag moves' : 'tags move'} to ${DatabaseService.defaultGroup}'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    final db = container.read(databaseProvider);
    switch (choice) {
      case 'rename':
        await _renameCategory(context, ref, group);
        return;
      case 'up' || 'down':
        await db.moveGroup(group, choice == 'up' ? -1 : 1, shown);
      case 'delete':
        await db.deleteGroup(group, kind);
    }
    _invalidateTags(container);
  }

  /// Renames a group for this kind's tags only; renaming to a group that
  /// already exists joins it.
  Future<void> _renameCategory(BuildContext context, WidgetRef ref, String name) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final renamed = await showNameDialog(context, title: 'Rename group', action: 'Rename', initial: name);
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
                  Icon(tagIcon(tag), size: 18, color: colors.leaf),
                  const SizedBox(width: 6),
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
  late String _group = widget.tag?.category ?? DatabaseService.defaultGroup;

  /// Groups made in this sheet, offered until the tag is saved into one.
  final _newGroups = <String>[];

  /// The dropdown item that makes a new group.
  static const _makeGroup = '\u0000new';
  late String _kind = widget.tag?.kind ?? TagKind.activity;

  /// The icon picked (a key of [tagIconChoices]); null for automatic.
  late String? _icon = widget.tag != null && pickedIcon(widget.tag!) != null
      ? widget.tag!.emoji.substring(pickedIconPrefix.length)
      : null;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// What goes in the tag's icon field: the picked icon, or back to the
  /// imported icon name (never a stale pick) when automatic.
  String get _emoji {
    if (_icon case final key?) return '$pickedIconPrefix$key';
    final old = widget.tag?.emoji;
    return old == null || old.startsWith(pickedIconPrefix) ? 'tag' : old;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final group = _group.trim().isEmpty ? DatabaseService.defaultGroup : _group.trim();
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
        await db.createTag(Tag(name: name, emoji: _emoji, category: group, kind: _kind));
        await db.moveTagsToGroup(const [], group); // makes sure the group exists
      } else {
        await db.updateTag(tag.copyWith(name: name, kind: _kind, emoji: _emoji));
        await db.moveTagsToGroup([tag.id!], group);
      }
    });
  }

  /// Asks for a new group's name; an existing one (any case) is reused.
  Future<String?> _askGroupName(List<String> existing) async {
    final name = await showNameDialog(context, title: 'New group', action: 'Add', hint: 'e.g. Errands');
    if (name == null || name.isEmpty) return null;
    return existing.firstWhere((g) => g.toLowerCase() == name.toLowerCase(), orElse: () => name);
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
    // This kind's groups in their order, the default, and any made here.
    final order = {for (final c in ref.watch(allTagCategoriesProvider).value ?? const <TagCategory>[]) c.name: c.sortOrder};
    final groups = {
      for (final t in ref.watch(allTagsProvider).value ?? const <Tag>[]) if (kindOf(t) == _kind) t.category,
      DatabaseService.defaultGroup,
      _group,
      ..._newGroups,
    }.toList()
      ..sort((a, b) => _byOrder(order[a], order[b], a, b));

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
            _IconPicker(
              preview: Tag(name: _name.text.trim(), emoji: _emoji, category: '', kind: _kind),
              picked: _icon,
              colors: colors,
              onPick: (key) => setState(() => _icon = key),
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
            DropdownButtonFormField<String>(
              // Rebuilt when the kind changes, so its groups are the ones offered.
              key: ValueKey(('group', _kind, _group, _newGroups.length)),
              initialValue: _group,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Group', helperText: 'Groups sort tags within a kind'),
              items: [
                for (final g in groups) DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis)),
                const DropdownMenuItem(
                  value: _makeGroup,
                  child: Row(children: [Icon(Icons.add, size: 18), SizedBox(width: 6), Text('New group…')]),
                ),
              ],
              onChanged: (value) async {
                if (value == null) return;
                if (value != _makeGroup) {
                  setState(() => _group = value);
                  return;
                }
                final made = await _askGroupName(groups);
                setState(() {
                  if (made != null && !groups.contains(made)) _newGroups.add(made);
                  if (made != null) _group = made;
                });
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
            if (tag != null && uses > 0) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: colors.accent),
                onPressed: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  navigator.push(MaterialPageRoute<void>(builder: (_) => TagCalendarScreen(tag: tag)));
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('See on calendar'),
              ),
            ],
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

/// Chooses a tag's icon: automatic (from its name) or one of
/// [tagIconChoices], with the result shown as it will look.
class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.preview, required this.picked, required this.colors, required this.onPick});

  /// The tag as it would be saved.
  final Tag preview;
  final String? picked;
  final GardenColors colors;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget option({required String? key, required IconData icon, required String label}) {
      final selected = picked == key;
      return Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: selected ? scheme.primaryContainer : colors.ground,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onPick(key),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 22, color: selected ? scheme.onPrimaryContainer : colors.leaf),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Icon', style: nunito(15, FontWeight.w800, colors.leaf)),
            const SizedBox(width: 10),
            Icon(tagIcon(preview), size: 20, color: colors.ink),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                picked == null ? 'Automatic, from the name' : 'Your pick',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nunito(13, FontWeight.w700, colors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Semantics(
              button: true,
              selected: picked == null,
              label: 'Automatic icon',
              excludeSemantics: true,
              child: ChoiceChip(
                label: const Text('Auto'),
                selected: picked == null,
                onSelected: (_) => onPick(null),
              ),
            ),
            for (final MapEntry(key: key, value: icon) in tagIconChoices.entries) option(key: key, icon: icon, label: '$key icon'),
          ],
        ),
      ],
    );
  }
}

/// Asks for a name in a dialog; null if cancelled. The dialog owns its text
/// field, so nothing is used after it closes.
Future<String?> showNameDialog(BuildContext context, {required String title, required String action, String initial = '', String? hint}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(title: title, action: action, initial: initial, hint: hint),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.action, required this.initial, this.hint});

  final String title;
  final String action;
  final String initial;
  final String? hint;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: 'Name', hintText: widget.hint),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text.trim()), child: Text(widget.action)),
      ],
    );
  }
}
