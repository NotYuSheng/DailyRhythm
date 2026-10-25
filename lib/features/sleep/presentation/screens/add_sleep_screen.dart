import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/sleep_entry.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../../data/providers/sleep_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/date_utils.dart';
import '../../../../shared/widgets/dialogs/delete_confirmation_dialog.dart';

/// Up to three of the most frequent times, rounded to 15 minutes, in clock order.
List<TimeOfDay> usualTimes(Iterable<DateTime?> times) {
  final counts = <int, int>{};
  for (final t in times.whereType<DateTime>()) {
    final minutes = ((t.hour * 60 + t.minute) / 15).round() * 15 % 1440;
    counts[minutes] = (counts[minutes] ?? 0) + 1;
  }
  final top = (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(3).map((e) => e.key).toList();
  // Bedtimes after midnight sort after the evening ones.
  top.sort((a, b) => ((a + 720) % 1440).compareTo((b + 720) % 1440));
  return [for (final m in top) TimeOfDay(hour: m ~/ 60, minute: m % 60)];
}

/// Rounded times just after [now] for a bedtime about to happen: the next
/// 5-minute mark, then the quarter hours after it, [count] in all.
List<TimeOfDay> laterTimes(DateTime now, {int count = 4}) {
  final minutes = now.hour * 60 + now.minute;
  final first = (minutes ~/ 5 + 1) * 5;
  final times = [first];
  while (times.length < count) {
    times.add((times.last ~/ 15 + 1) * 15);
  }
  return [for (final m in times) TimeOfDay(hour: m ~/ 60 % 24, minute: m % 60)];
}

class AddSleepScreen extends ConsumerStatefulWidget {
  final SleepEntry? entry; // For editing existing entries
  final DateTime? date; // For specifying the date when creating new entries

  const AddSleepScreen({super.key, this.entry, this.date});

  @override
  ConsumerState<AddSleepScreen> createState() => _AddSleepScreenState();
}

class _AddSleepScreenState extends ConsumerState<AddSleepScreen> {
  late DateTime _date;
  DateTime? _sleepTime;
  DateTime? _wakeUpTime;
  final TextEditingController _napHoursController = TextEditingController();
  DateTime? _previousDaySleepTime;
  List<TimeOfDay> _usualWake = const [];
  List<TimeOfDay> _usualBed = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = widget.entry?.date ?? widget.date ?? DateTime(now.year, now.month, now.day);
    _sleepTime = widget.entry?.sleepTime;
    _wakeUpTime = widget.entry?.wakeUpTime;
    _napHoursController.text = widget.entry?.napHours?.toString() ?? '';
    _loadPreviousDaySleepTime();
    _loadUsualTimes();
  }

  /// Your most common wake and bed times over the last month, rounded to
  /// 15 minutes, offered as one-tap choices.
  Future<void> _loadUsualTimes() async {
    final entries = await ref
        .read(databaseProvider)
        .getSleepEntriesInRange(_date.subtract(const Duration(days: 30)), _date.subtract(const Duration(days: 1)));
    if (mounted) {
      setState(() {
        _usualWake = usualTimes(entries.map((e) => e.wakeUpTime));
        _usualBed = usualTimes(entries.map((e) => e.sleepTime));
      });
    }
  }

  Future<void> _loadPreviousDaySleepTime() async {
    final db = ref.read(databaseProvider);
    final previousDate = _date.subtract(const Duration(days: 1));
    final previousEntry = await db.getSleepEntryByDate(previousDate);
    if (mounted) {
      setState(() {
        _previousDaySleepTime = previousEntry?.sleepTime;
      });
    }
  }

  @override
  void dispose() {
    _napHoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'Sleep' : 'Edit sleep'),
        actions: [
          if (widget.entry != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
            ),
          TextButton(
            onPressed: _saveSleep,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        children: [
          // Wake Up Time
          _buildTimePicker(
            label: 'Woke up',
            time: _wakeUpTime,
            usual: _usualWake,
            fallback: const TimeOfDay(hour: 8, minute: 0),
            onSelect: (time) => setState(() => _wakeUpTime = time),
          ),
          const SizedBox(height: AppTheme.spacePulse3),

          // Sleep Time
          _buildTimePicker(
            label: 'Went to bed',
            time: _sleepTime,
            usual: _usualBed,
            soon: true,
            fallback: const TimeOfDay(hour: 23, minute: 0),
            onSelect: (time) => setState(() => _sleepTime = time),
          ),
          const SizedBox(height: AppTheme.spacePulse3),

          // Nap Hours
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacePulse3),
              child: TextField(
                controller: _napHoursController,
                decoration: const InputDecoration(
                  labelText: 'Nap Hours',
                  hintText: 'Enter hours (e.g., 1.5)',
                  suffixText: 'hours',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacePulse3),

          // Total Hours (auto-calculated from previous night)
          if (_previousDaySleepTime != null && _wakeUpTime != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacePulse3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Sleep (Last Night)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${_calculateHours()?.toStringAsFixed(1) ?? 'unknown'}h',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacePulse1),
                    if (_previousDaySleepTime != null && _wakeUpTime != null)
                      Text(
                        'From ${DateFormat('h:mm a').format(_previousDaySleepTime!)} to ${DateFormat('h:mm a').format(_wakeUpTime!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            )
          else if (_wakeUpTime != null && _previousDaySleepTime == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacePulse3),
                child: Text(
                  'No sleep time recorded for previous day',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required DateTime? time,
    required List<TimeOfDay> usual,
    required TimeOfDay fallback,
    required ValueChanged<DateTime?> onSelect,
    bool soon = false,
  }) {
    final format = DateFormat('HH:mm');
    final now = DateTime.now();
    final isToday = dayOf(now) == dayOf(_date);
    final selected = time == null ? null : TimeOfDay.fromDateTime(time);
    // Today: Now first; for bedtime also the next few rounded times, since
    // it is often logged just before going to bed. Then the usual times.
    final choices = <TimeOfDay>[];
    for (final t in [
      if (isToday) TimeOfDay.fromDateTime(now),
      if (isToday && soon) ...laterTimes(now),
      ...usual,
    ]) {
      if (!choices.contains(t)) choices.add(t);
    }

    Future<void> pickOther() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: selected ?? (usual.isNotEmpty ? usual.first : fallback),
        // Typing is quicker than the dial, especially on desktop.
        initialEntryMode: TimePickerEntryMode.input,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
      if (picked != null) onSelect(atTimeOfDay(_date, picked.hour, picked.minute));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
                Text(time == null ? 'Not set' : format.format(time), style: Theme.of(context).textTheme.titleLarge),
                if (time != null)
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close),
                    onPressed: () => onSelect(null),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacePulse2),
            Wrap(
              spacing: AppTheme.spacePulse2,
              runSpacing: AppTheme.spacePulse2,
              children: [
                for (final (i, t) in choices.indexed)
                  ChoiceChip(
                    label: Text(isToday && i == 0 ? 'Now' : t.format24()),
                    selected: !(isToday && i == 0) && selected == t,
                    onSelected: (_) => onSelect(atTimeOfDay(_date, t.hour, t.minute)),
                  ),
                ActionChip(label: const Text('Other\u2026'), onPressed: pickOther),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double? _calculateHours() {
    // Calculate total sleep hours for THIS day's entry
    // Formula: (Previous day's recorded bedtime) to (This day's wake-up time)
    //
    // Example: If you went to bed on Dec 24 at 11 PM and woke up Dec 25 at 7 AM,
    // then Dec 25's sleep entry will have:
    //   - sleepTime: user's input for Dec 25 bedtime (stored for Dec 26's calculation)
    //   - wakeUpTime: 7 AM on Dec 25
    //   - totalHours: calculated from Dec 24's sleepTime (11 PM) to Dec 25's wakeUpTime (7 AM) = 8 hours
    //
    // If previous day's sleep time was not recorded, return null to show "unknown"
    if (_previousDaySleepTime == null || _wakeUpTime == null) return null;
    return sleepDurationHours(_previousDaySleepTime!, _wakeUpTime!);
  }

  Future<void> _saveSleep() async {
    // Either time is enough: in the morning you only know when you woke up.
    if (_sleepTime == null && _wakeUpTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set when you woke up or went to bed')),
      );
      return;
    }

    // Parse nap hours
    double? napHours;
    if (_napHoursController.text.isNotEmpty) {
      napHours = double.tryParse(_napHoursController.text);
      if (napHours == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid number for nap hours')),
        );
        return;
      }
    }

    final db = ref.read(databaseProvider);

    // - sleepTime: When user went to bed TODAY (used for NEXT day's total)
    //              Note: This could be past midnight (e.g., went to bed at 1 AM)
    // - wakeUpTime: When user woke up today
    // The database computes totalHours from the previous day's bedtime.
    final entry = SleepEntry(
      id: widget.entry?.id,
      date: _date,
      sleepTime: _sleepTime,
      wakeUpTime: _wakeUpTime,
      napHours: napHours,
    );

    try {
      await db.saveSleepEntry(entry);

      ref.invalidate(sleepEntriesProvider(_date));
      ref.invalidate(sleepEntriesProvider(DateTime(_date.year, _date.month, _date.day + 1)));
      ref.invalidate(todaySleepEntriesProvider);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().split('\n').first}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDeleteConfirmationDialog(
      context: context,
      title: 'Delete Sleep Entry',
      message: 'Are you sure you want to delete this sleep entry?',
    );
    if (!confirmed || widget.entry?.id == null) return;

    await ref.read(databaseProvider).deleteSleepEntry(widget.entry!.id!);
    ref.invalidate(sleepEntriesProvider(widget.entry!.date));
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Sleep entry deleted'), duration: Duration(seconds: 2)),
    );
  }
}

extension on TimeOfDay {
  String format24() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
