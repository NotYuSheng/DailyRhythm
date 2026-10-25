import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/sleep_entry.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../../data/providers/sleep_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/date_utils.dart';
import '../../../../shared/widgets/dialogs/delete_confirmation_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = widget.entry?.date ?? widget.date ?? DateTime(now.year, now.month, now.day);
    _sleepTime = widget.entry?.sleepTime;
    _wakeUpTime = widget.entry?.wakeUpTime;
    _napHoursController.text = widget.entry?.napHours?.toString() ?? '';
    _loadPreviousDaySleepTime();
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
        title: Text(widget.entry == null ? 'Add Sleep' : 'Edit Sleep'),
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
            label: 'Wake Up Time',
            time: _wakeUpTime,
            onSelect: (time) => setState(() => _wakeUpTime = time),
          ),
          const SizedBox(height: AppTheme.spacePulse3),

          // Sleep Time
          _buildTimePicker(
            label: 'Sleep Time',
            time: _sleepTime,
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
                  border: OutlineInputBorder(),
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
                          color: Colors.grey,
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
                    color: Colors.grey,
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
    required Function(DateTime) onSelect,
  }) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(
          time != null ? DateFormat('h:mm a').format(time) : 'Not set',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        onTap: () async {
          // Default to 8:30 AM for wake up time if not set, otherwise use current time
          final defaultTime = label == 'Wake Up Time' && time == null
              ? TimeOfDay(hour: 8, minute: 30)
              : TimeOfDay.fromDateTime(time ?? DateTime.now());

          final pickedTime = await showTimePicker(
            context: context,
            initialTime: defaultTime,
          );
          if (pickedTime != null) {
            onSelect(atTimeOfDay(_date, pickedTime.hour, pickedTime.minute));
          }
        },
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
    if (_sleepTime == null || _wakeUpTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set both sleep and wake times')),
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
