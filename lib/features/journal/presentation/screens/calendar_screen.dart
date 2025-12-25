import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:unicons/unicons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/common_providers.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  final Function(DateTime)? onDateSelected;

  const CalendarScreen({super.key, this.onDateSelected});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                  color: theme.colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                ),
                selectedDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
                outsideDaysVisible: false,
                disabledTextStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final normalizedDay = DateTime(day.year, day.month, day.day);
                  final moodAsync = ref.watch(moodEntryProvider(normalizedDay));

                  return moodAsync.when(
                    data: (mood) => _HoverableDay(
                      day: day,
                      isToday: isSameDay(day, DateTime.now()),
                      isSelected: isSameDay(day, _selectedDay),
                      moodLevel: mood?.moodLevel,
                      isDark: isDark,
                    ),
                    loading: () => _HoverableDay(
                      day: day,
                      isToday: isSameDay(day, DateTime.now()),
                      isSelected: isSameDay(day, _selectedDay),
                      isDark: isDark,
                    ),
                    error: (_, __) => _HoverableDay(
                      day: day,
                      isToday: isSameDay(day, DateTime.now()),
                      isSelected: isSameDay(day, _selectedDay),
                      isDark: isDark,
                    ),
                  );
                },
              ),
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: theme.textTheme.titleLarge!,
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: theme.iconTheme.color,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: theme.iconTheme.color,
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
              style: theme.textTheme.bodyMedium,
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
  final int? moodLevel;
  final bool isDark;

  const _HoverableDay({
    required this.day,
    required this.isToday,
    required this.isSelected,
    this.moodLevel,
    this.isDark = false,
  });

  @override
  State<_HoverableDay> createState() => _HoverableDayState();
}

class _HoverableDayState extends State<_HoverableDay> {
  bool _isHovered = false;

  IconData _getMoodIcon(int moodLevel) {
    switch (moodLevel) {
      case 1:
        return UniconsLine.sad_crying;
      case 2:
        return UniconsLine.frown;
      case 3:
        return UniconsLine.meh;
      case 4:
        return UniconsLine.smile;
      case 5:
        return UniconsLine.grin;
      default:
        return UniconsLine.meh;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? theme.colorScheme.primary
              : widget.isToday
                  ? theme.colorScheme.secondaryContainer
                  : _isHovered
                      ? (isDark ? AppTheme.grey800 : AppTheme.grey100)
                      : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '${widget.day.day}',
                style: TextStyle(
                  color: widget.isSelected
                      ? theme.colorScheme.onPrimary
                      : widget.isToday
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onSurface,
                  fontWeight: widget.isToday || widget.isSelected
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            // Mood indicator
            if (widget.moodLevel != null)
              Positioned(
                bottom: 2,
                right: 2,
                child: Icon(
                  _getMoodIcon(widget.moodLevel!),
                  size: 14,
                  color: widget.isSelected
                      ? theme.colorScheme.onPrimary
                      : widget.isToday
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
