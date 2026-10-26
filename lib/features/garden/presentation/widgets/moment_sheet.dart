import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/services/database/repositories/journal_repository.dart';
import '../../../journal/data/models/journal_entry.dart';
import '../../../tags/data/models/tag.dart';
import '../../../tags/data/providers/tag_providers.dart';
import '../garden_style.dart';

const momentMoodWords = {1: 'Awful', 2: 'Bad', 3: 'Meh', 4: 'Good', 5: 'Great'};

/// Opens the sheet for logging a moment on [day]. Returns true if saved.
Future<bool> showMomentSheet(BuildContext context, DateTime day) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => MomentSheet(day: day),
  );
  return saved ?? false;
}

/// A moment: what happened, an optional mood of its own and what it was about.
class MomentSheet extends ConsumerStatefulWidget {
  const MomentSheet({super.key, required this.day});

  final DateTime day;

  @override
  ConsumerState<MomentSheet> createState() => _MomentSheetState();
}

class _MomentSheetState extends ConsumerState<MomentSheet> {
  final _text = TextEditingController();
  int? _mood;
  final _tagIds = <int>{};
  bool _saving = false;

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
    await JournalRepository(ref.read(databaseProvider)).save(JournalEntry(
      date: day,
      time: isToday ? now : null,
      text: _text.text.trim(),
      mood: _mood,
      tagIds: _tagIds.toList(),
    ));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    final tags = ref.watch(allTagsProvider).value ?? const <Tag>[];
    final about = [for (final t in tags) if (t.kind != TagKind.foodSource) t];

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('A moment', style: nunito(22, FontWeight.w900, colors.ink)),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              autofocus: true,
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in about)
                    FilterChip(
                      label: Text(tag.name),
                      selected: _tagIds.contains(tag.id),
                      onSelected: (on) => setState(() => on ? _tagIds.add(tag.id!) : _tagIds.remove(tag.id)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _canSave && !_saving ? _save : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: colors.accent,
                foregroundColor: colors.onAccent,
              ),
              child: Text('Save moment', style: nunito(15, FontWeight.w900, colors.onAccent)),
            ),
          ],
        ),
      ),
    );
  }
}
