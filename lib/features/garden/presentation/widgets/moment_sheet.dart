import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/services/database/repositories/journal_repository.dart';
import '../../../../shared/widgets/dialogs/delete_confirmation_dialog.dart';
import '../../../journal/data/models/journal_entry.dart';
import '../../../tags/data/models/tag.dart';
import '../../../tags/data/providers/tag_providers.dart';
import '../../../tags/presentation/tag_icons.dart';
import '../garden_style.dart';

const momentMoodWords = {1: 'Awful', 2: 'Bad', 3: 'Meh', 4: 'Good', 5: 'Great'};

/// Opens the sheet for logging a moment on [day], or changing [entry].
/// Returns true if it was saved or deleted.
Future<bool> showMomentSheet(BuildContext context, DateTime day, {JournalEntry? entry}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => MomentSheet(day: day, entry: entry),
  );
  return saved ?? false;
}

/// A moment: what happened, an optional mood of its own and what it was about.
class MomentSheet extends ConsumerStatefulWidget {
  const MomentSheet({super.key, required this.day, this.entry});

  final DateTime day;

  /// The moment being changed; null for a new one.
  final JournalEntry? entry;

  @override
  ConsumerState<MomentSheet> createState() => _MomentSheetState();
}

class _MomentSheetState extends ConsumerState<MomentSheet> {
  late final _text = TextEditingController(text: widget.entry?.text ?? '');
  late int? _mood = widget.entry?.mood;
  late final _tagIds = <int>{...?widget.entry?.tagIds};
  bool _saving = false;

  bool get _editing => widget.entry != null;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _canSave => _text.text.trim().isNotEmpty || _mood != null || _tagIds.isNotEmpty;

  Future<void> _save() async {
    setState(() => _saving = true);
    final now = DateTime.now();
    final day = widget.day;
    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
    try {
      final old = widget.entry;
      await JournalRepository(ref.read(databaseProvider)).save(JournalEntry(
        // A change keeps the moment's day, time and where it came from.
        id: old?.id,
        date: old?.date ?? day,
        time: old == null ? (isToday ? now : null) : old.time,
        source: old?.source ?? 'app',
        createdAt: old?.createdAt,
        text: _text.text.trim(),
        mood: _mood,
        tagIds: _tagIds.toList(),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t save the moment. Try again.')));
      return;
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final sure = await showDeleteConfirmationDialog(context: context, title: 'Delete this moment?', message: 'It can’t be brought back.');
    if (!sure || !mounted) return;
    setState(() => _saving = true);
    await JournalRepository(ref.read(databaseProvider)).delete(widget.entry!.id!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    final tags = ref.watch(allTagsProvider).value ?? const <Tag>[];
    final about = [for (final t in tags) if (t.kind != TagKind.foodSource) t];
    final order = {for (final c in ref.watch(allTagCategoriesProvider).value ?? const <TagCategory>[]) c.name: c.sortOrder ?? 0};
    final groups = <String, List<Tag>>{};
    for (final t in about) {
      (groups[t.category] ??= []).add(t);
    }
    // In the user's category order, symptoms last: a long list that's
    // rarely what a moment is about.
    bool symptoms(String category) => groups[category]!.every((t) => t.kind == TagKind.symptom);
    final categories = groups.keys.toList()
      ..sort((a, b) {
        final bySymptoms = (symptoms(a) ? 1 : 0).compareTo(symptoms(b) ? 1 : 0);
        return bySymptoms != 0 ? bySymptoms : (order[a] ?? 1 << 20).compareTo(order[b] ?? 1 << 20);
      });

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_editing ? 'Edit moment' : 'A moment', style: nunito(22, FontWeight.w900, colors.ink)),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              // Straight to typing for a new moment; a change may be just a tag.
              autofocus: !_editing,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'What happened?'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text('How it felt (optional)', style: nunito(15, FontWeight.w800, colors.ink)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final MapEntry(key: level, value: word) in momentMoodWords.entries)
                  ChoiceChip(
                    label: Text(word),
                    selected: _mood == level,
                    onSelected: (on) => setState(() => _mood = on ? level : null),
                  ),
              ],
            ),
            if (about.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('About (optional)', style: nunito(15, FontWeight.w800, colors.ink)),
              for (final category in categories) ...[
                const SizedBox(height: 10),
                Text(category, style: nunito(13, FontWeight.w800, colors.leaf)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in groups[category]!)
                      FilterChip(
                        avatar: Icon(tagIcon(tag), size: 18),
                        showCheckmark: false,
                        label: Text(tag.name),
                        selected: _tagIds.contains(tag.id),
                        onSelected: (on) => setState(() => on ? _tagIds.add(tag.id!) : _tagIds.remove(tag.id)),
                      ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _canSave && !_saving ? _save : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: colors.accent,
                foregroundColor: colors.onAccent,
              ),
              child: Text(_editing ? 'Save changes' : 'Save moment', style: nunito(15, FontWeight.w900, colors.onAccent)),
            ),
            if (_editing) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44), foregroundColor: Theme.of(context).colorScheme.error),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete moment'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
