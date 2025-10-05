import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme/app_theme.dart';

class CalendarScreen extends StatefulWidget {
  final Function(DateTime)? onDateSelected;

  const CalendarScreen({super.key, this.onDateSelected});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(AppTheme.spacePulse3),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.now(),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                if (selectedDay.isAfter(DateTime.now())) {
                  return;
                }
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });

                // Call the callback to switch tabs and pass selected date
                widget.onDateSelected?.call(selectedDay);
              },
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month',
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppTheme.rhythmMediumGray,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: AppTheme.rhythmBlack,
                  shape: BoxShape.circle,
                ),
                outsideDaysVisible: false,
                disabledTextStyle: TextStyle(
                  color: AppTheme.rhythmLightGray,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  return _HoverableDay(
                    day: day,
                    isToday: isSameDay(day, DateTime.now()),
                    isSelected: isSameDay(day, _selectedDay),
                  );
                },
              ),
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: Theme.of(context).textTheme.titleLarge!.copyWith(
                      color: AppTheme.rhythmBlack,
                    ),
                leftChevronIcon: const Icon(
                  Icons.chevron_left,
                  color: AppTheme.rhythmBlack,
                ),
                rightChevronIcon: const Icon(
                  Icons.chevron_right,
                  color: AppTheme.rhythmBlack,
                ),
              ),
              enabledDayPredicate: (day) {
                return !day.isAfter(DateTime.now());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacePulse3),
            child: Text(
              'Select a date to view entries',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.rhythmMediumGray,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverableDay extends StatefulWidget {
  final DateTime day;
  final bool isToday;
  final bool isSelected;

  const _HoverableDay({
    required this.day,
    required this.isToday,
    required this.isSelected,
  });

  @override
  State<_HoverableDay> createState() => _HoverableDayState();
}

class _HoverableDayState extends State<_HoverableDay> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? AppTheme.rhythmBlack
              : widget.isToday
                  ? AppTheme.rhythmMediumGray
                  : _isHovered
                      ? AppTheme.rhythmLightGray
                      : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${widget.day.day}',
            style: TextStyle(
              color: widget.isSelected
                  ? AppTheme.rhythmWhite
                  : AppTheme.rhythmBlack,
              fontWeight: widget.isToday || widget.isSelected
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
