import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/database/database_provider.dart';
import '../../../shared/utils/date_utils.dart';
import '../../../shared/widgets/dialogs/delete_confirmation_dialog.dart';
import '../../exercise/domain/effort.dart';
import '../data/learning_entry.dart';
import '../data/learning_providers.dart';
import '../data/learning_repository.dart';

/// Logs or edits something learnt: one line, quick to add between tasks,
/// with a topic, how it came about and, if wanted, a reflection.
class AddLearningScreen extends ConsumerStatefulWidget {
  const AddLearningScreen({super.key, this.entry, this.date});

  final LearningEntry? entry;

  /// Day to log a new entry on (defaults to today).
  final DateTime? date;

  @override
  ConsumerState<AddLearningScreen> createState() => _AddLearningScreenState();
}

class _AddLearningScreenState extends ConsumerState<AddLearningScreen> {
  late final _what = TextEditingController(text: widget.entry?.what ?? '');
  late final _soWhat = TextEditingController(text: widget.entry?.soWhat ?? '');
  late final _nowWhat = TextEditingController(text: widget.entry?.nowWhat ?? '');
  late final _topic = TextEditingController(text: widget.entry?.topic ?? '');
  late final _minutes = TextEditingController(text: widget.entry?.minutes?.toString() ?? '');
  final _topicFocus = FocusNode();
  late String _how = widget.entry?.how ?? LearningHow.work;
  late int? _rpe = widget.entry?.rpe;
  late bool _reflect = (widget.entry?.soWhat ?? widget.entry?.nowWhat) != null;
  bool _saving = false;

  static const _quickMinutes = [15, 30, 60, 120];

  @override
  void initState() {
    super.initState();
    _minutes.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_what, _soWhat, _nowWhat, _topic, _minutes]) {
      c.dispose();
    }
    _topicFocus.dispose();
    super.dispose();
  }

  static String? _text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (_saving) return;
    final what = _what.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (what.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Say what you learnt, in a line')));
      return;
    }
    final minutesText = _minutes.text.trim();
    final minutes = minutesText.isEmpty ? null : int.tryParse(minutesText);
    if (minutesText.isNotEmpty && (minutes == null || minutes <= 0)) {
      messenger.showSnackBar(const SnackBar(content: Text('Time spent is in whole minutes')));
      return;
    }
    final now = DateTime.now();
    final day = dayOf(widget.entry?.date ?? widget.date ?? now);
    final old = widget.entry;
    // Read before awaiting: the screen may be gone by the time it's saved.
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    await LearningRepository(container.read(databaseProvider)).save(LearningEntry(
      id: old?.id,
      date: day,
      time: old?.time ?? atTimeOfDay(day, now.hour, now.minute),
      what: what,
      soWhat: _text(_soWhat),
      nowWhat: _text(_nowWhat),
      topic: _text(_topic),
      how: _how,
      minutes: minutes,
      rpe: _rpe,
    ));
    container.invalidate(learningProvider(day));
    container.invalidate(learningTopicsProvider);
    if (mounted) navigator.pop();
  }

  Future<void> _delete() async {
    final container = ProviderScope.containerOf(context, listen: false);
    final confirmed = await showDeleteConfirmationDialog(context: context, title: 'Delete this entry', message: 'Delete “${widget.entry!.what}”?');
    if (!confirmed) return;
    await LearningRepository(container.read(databaseProvider)).delete(widget.entry!.id!);
    container.invalidate(learningProvider(dayOf(widget.entry!.date)));
    container.invalidate(learningTopicsProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topics = ref.watch(learningTopicsProvider).value ?? const <String>[];
    final small = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'Something learnt' : 'Edit what you learnt'),
        actions: [
          if (widget.entry?.id != null) IconButton(icon: const Icon(Icons.delete), tooltip: 'Delete', onPressed: _delete),
          TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacePulse3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _what,
                    autofocus: widget.entry == null,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'What I learnt', hintText: 'One line is enough'),
                  ),
                  const SizedBox(height: AppTheme.spacePulse3),
                  RawAutocomplete<String>(
                    textEditingController: _topic,
                    focusNode: _topicFocus,
                    optionsBuilder: (value) {
                      final typed = value.text.trim().toLowerCase();
                      return topics.where((t) => t.toLowerCase().contains(typed) && t.toLowerCase() != typed).take(5);
                    },
                    fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Topic (optional)', hintText: 'e.g. Flutter, Negotiation'),
                    ),
                    optionsViewBuilder: (context, onSelected, options) => Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220, maxWidth: 320),
                          child: ListView(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            children: [for (final t in options) ListTile(dense: true, title: Text(t), onTap: () => onSelected(t))],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (topics.isNotEmpty && _topic.text.isEmpty) ...[
                    const SizedBox(height: AppTheme.spacePulse2),
                    Wrap(
                      spacing: AppTheme.spacePulse2,
                      runSpacing: AppTheme.spacePulse1,
                      children: [
                        for (final t in topics.take(5)) ActionChip(label: Text(t), onPressed: () => setState(() => _topic.text = t)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacePulse3),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacePulse3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How it came about', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppTheme.spacePulse2),
                  Wrap(
                    spacing: AppTheme.spacePulse2,
                    runSpacing: AppTheme.spacePulse2,
                    children: [
                      for (final h in LearningHow.all)
                        ChoiceChip(label: Text(LearningHow.labels[h]!), selected: _how == h, onSelected: (_) => setState(() => _how = h)),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacePulse3),
                  Text('Time spent (optional)', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppTheme.spacePulse2),
                  Wrap(
                    spacing: AppTheme.spacePulse2,
                    runSpacing: AppTheme.spacePulse2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final m in _quickMinutes)
                        ChoiceChip(
                          label: Text(m < 60 ? '${m}m' : '${m ~/ 60}h'),
                          selected: _minutes.text.trim() == '$m',
                          onSelected: (on) => _minutes.text = on ? '$m' : '',
                        ),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _minutes,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Minutes', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacePulse3),
                  Text('How hard was it? (optional)', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppTheme.spacePulse2),
                  Wrap(
                    spacing: AppTheme.spacePulse2,
                    runSpacing: AppTheme.spacePulse2,
                    children: [
                      for (final MapEntry(key: rpe, value: label) in Effort.felt.entries)
                        ChoiceChip(label: Text(label), selected: _rpe == rpe, onSelected: (on) => setState(() => _rpe = on ? rpe : null)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacePulse3),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacePulse3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reflect on it'),
                    subtitle: const Text('So what, and now what? Optional'),
                    value: _reflect,
                    onChanged: (v) => setState(() => _reflect = v),
                  ),
                  if (_reflect) ...[
                    TextField(
                      controller: _soWhat,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'So what?', hintText: 'Why it matters, what it changes'),
                    ),
                    const SizedBox(height: AppTheme.spacePulse3),
                    TextField(
                      controller: _nowWhat,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Now what?', hintText: 'What you’ll do with it'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacePulse2),
          Text('Only “What I learnt” is needed; the rest is for when you have a moment.', style: small),
        ],
      ),
    );
  }
}
