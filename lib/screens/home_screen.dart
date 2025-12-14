import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'journal_screen.dart';
import 'calendar_screen.dart';
import 'metrics_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  DateTime? _selectedDate;

  List<Widget> get _screens => [
        JournalScreen(
          initialDate: _selectedDate,
          onTodayPressed: () {
            setState(() {
              _selectedDate = null;
            });
          },
          onDateChanged: (date) {
            setState(() {
              _selectedDate = date;
            });
          },
        ),
        CalendarScreen(
          onDateSelected: (date) {
            setState(() {
              _selectedDate = date;
              _currentIndex = 0; // Switch to Journal tab
            });
          },
        ),
        const MetricsScreen(),
        const SettingsScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outline,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.book_outlined),
              activeIcon: Icon(Icons.book),
              label: 'Journal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics),
              label: 'Metrics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
