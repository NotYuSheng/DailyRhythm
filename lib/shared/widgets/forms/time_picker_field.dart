import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A reusable time picker widget wrapped in a Card with ListTile
/// Displays a label and the selected time, opens time picker dialog on tap
class TimePickerField extends StatelessWidget {
  final String label;
  final DateTime? time;
  final Function(DateTime) onSelect;
  final TimeOfDay? defaultTime;

  const TimePickerField({
    super.key,
    required this.label,
    required this.time,
    required this.onSelect,
    this.defaultTime,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(
          time != null ? DateFormat('h:mm a').format(time!) : 'Not set',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        onTap: () async {
          // Use provided default time, or fall back to current time
          final initialTime = defaultTime ?? TimeOfDay.fromDateTime(time ?? DateTime.now());

          final pickedTime = await showTimePicker(
            context: context,
            initialTime: initialTime,
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
}
