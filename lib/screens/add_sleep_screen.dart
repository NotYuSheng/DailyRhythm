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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = widget.entry?.date ?? DateTime(now.year, now.month, now.day);
    _sleepTime = widget.entry?.sleepTime;
    _wakeUpTime = widget.entry?.wakeUpTime;
    _napHoursController.text = widget.entry?.napHours?.toString() ?? '';
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

          // Total Hours (auto-calculated)
          if (_sleepTime != null && _wakeUpTime != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacePulse3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Sleep',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${_calculateHours().toStringAsFixed(1)}h',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ],
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
          final pickedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(time ?? DateTime.now()),
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
    if (_sleepTime == null || _wakeUpTime == null) return 0;

    var duration = _wakeUpTime!.difference(_sleepTime!);

    // If wake time is before sleep time, assume it's the next day
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

      if (widget.entry == null) {
        await db.createSleepEntry(entry);
      } else {
        await db.updateSleepEntry(entry);
      }

      // Refresh current day's sleep data
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
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
