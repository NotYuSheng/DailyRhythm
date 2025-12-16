import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/sleep_entry.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';

class AddSleepScreen extends ConsumerStatefulWidget {
  final SleepEntry? entry; // For editing existing entries

  const AddSleepScreen({super.key, this.entry});

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
    _date = widget.entry?.date ?? DateTime(now.year, now.month, now.day);
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
                          '${_calculateHours().toStringAsFixed(1)}h',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacePulse1),
                    Text(
                      'From ${DateFormat('MMM d, h:mm a').format(_previousDaySleepTime!)} to ${DateFormat('h:mm a').format(_wakeUpTime!)}',
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
            final now = DateTime.now();
            onSelect(DateTime(
              now.year,
              now.month,
              now.day,
              pickedTime.hour,
              pickedTime.minute,
            ));
          }
        },
      ),
    );
  }

  double _calculateHours() {
    // Calculate sleep from previous day's sleep time to today's wake time
    if (_previousDaySleepTime == null || _wakeUpTime == null) return 0;

    var duration = _wakeUpTime!.difference(_previousDaySleepTime!);

    // If duration is negative, add a day (shouldn't normally happen)
    if (duration.isNegative) {
      duration = duration + const Duration(days: 1);
    }

    return duration.inMinutes / 60.0;
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

    final entry = SleepEntry(
      id: widget.entry?.id,
      date: _date,
      sleepTime: _sleepTime,
      wakeUpTime: _wakeUpTime,
      totalHours: _calculateHours(),
      napHours: napHours,
    );

    try {
      final db = ref.read(databaseProvider);

      // Use upsert to either create or update entry for this date
      await db.upsertSleepEntry(entry);

      // Refresh sleep data for this date
      ref.invalidate(sleepEntriesProvider(_date));
      ref.invalidate(todaySleepEntriesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sleep entry saved!')),
        );
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

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Sleep Entry'),
          content: const Text('Are you sure you want to delete this sleep entry?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (widget.entry?.id != null) {
                  final db = ref.read(databaseProvider);
                  await db.deleteSleepEntry(widget.entry!.id!);

                  if (mounted) {
                    // Invalidate the provider to refresh the list
                    ref.invalidate(sleepEntriesProvider(widget.entry!.date));

                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close edit screen

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sleep entry deleted'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: AppTheme.rhythmBlack)),
            ),
          ],
        );
      },
    );
  }
}
