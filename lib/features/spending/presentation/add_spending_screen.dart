import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/spending_entry.dart';
import '../../../shared/services/database/database_provider.dart';
import '../../../shared/services/database/repositories/spending_repository.dart';
import '../../../shared/utils/date_utils.dart';
import '../../../shared/widgets/dialogs/delete_confirmation_dialog.dart';
import '../data/spending_providers.dart';

/// Logs or edits an event or gift: spending that isn't a meal.
class AddSpendingScreen extends ConsumerStatefulWidget {
  const AddSpendingScreen({super.key, this.entry, this.date});

  final SpendingEntry? entry;

  /// Day to log a new entry on (defaults to today).
  final DateTime? date;

  @override
  ConsumerState<AddSpendingScreen> createState() => _AddSpendingScreenState();
}

class _AddSpendingScreenState extends ConsumerState<AddSpendingScreen> {
  late final _label = TextEditingController(text: widget.entry?.label ?? '');
  late final _amount = TextEditingController(text: _format(widget.entry?.amount));
  late final _notes = TextEditingController(text: widget.entry?.notes ?? '');
  late String _category = widget.entry?.category ?? SpendingEntry.event;
  bool _saving = false;

  static String _format(double? v) =>
      v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2));

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final label = _label.text.trim();
    final amount = double.tryParse(_amount.text.trim());
    final messenger = ScaffoldMessenger.of(context);
    if (label.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Say what it was for')));
      return;
    }
    if (amount == null || amount < 0) {
      messenger.showSnackBar(const SnackBar(content: Text('Please enter a valid amount')));
      return;
    }
    final now = DateTime.now();
    final day = dayOf(widget.entry?.date ?? widget.date ?? now);
    final old = widget.entry;
    // Read before awaiting: the screen may be gone by the time it's saved.
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    await SpendingRepository(container.read(databaseProvider)).save(SpendingEntry(
      id: old?.id,
      date: day,
      time: old == null ? atTimeOfDay(day, now.hour, now.minute) : old.time,
      label: label,
      amount: amount,
      currency: old?.currency ?? 'SGD',
      category: _category,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      rawText: old?.rawText,
    ));
    container.invalidate(spendingProvider(day));
    if (mounted) navigator.pop();
  }

  Future<void> _delete() async {
    final container = ProviderScope.containerOf(context, listen: false);
    final confirmed = await showDeleteConfirmationDialog(
      context: context,
      title: 'Delete this entry',
      message: 'Delete ${widget.entry!.label}?',
    );
    if (!confirmed) return;
    await SpendingRepository(container.read(databaseProvider)).delete(widget.entry!.id!);
    container.invalidate(spendingProvider(dayOf(widget.entry!.date)));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'Event or gift' : 'Edit event or gift'),
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
                    controller: _label,
                    autofocus: widget.entry == null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'What for', hintText: 'A farewell dinner, a wedding…'),
                  ),
                  const SizedBox(height: AppTheme.spacePulse3),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Amount', prefixText: '${widget.entry?.currency == null || widget.entry!.currency == 'SGD' ? '\$' : '${widget.entry!.currency} '} '),
                  ),
                  const SizedBox(height: AppTheme.spacePulse3),
                  Wrap(
                    spacing: AppTheme.spacePulse2,
                    children: [
                      for (final c in SpendingEntry.categories)
                        ChoiceChip(
                          label: Text(SpendingEntry.labels[c]!),
                          selected: _category == c,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacePulse3),
                  TextField(
                    controller: _notes,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacePulse2),
          Text(
            'Events and gifts aren’t counted as food spending.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
