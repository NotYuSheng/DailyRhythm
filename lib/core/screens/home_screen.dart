import 'package:material_ui/material_ui.dart';
import '../../features/garden/presentation/screens/garden_today_screen.dart';
import '../../features/journal/presentation/screens/journal_screen.dart';
import '../../features/journal/presentation/screens/calendar_screen.dart';
import '../../features/metrics/presentation/screens/metrics_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  DateTime? _selectedDate;

  List<Widget> get _screens => [
        const GardenTodayScreen(),
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
              _currentIndex = 1; // Switch to Journal tab
            });
          },
        ),
        const MetricsScreen(),
        const SettingsScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_florist_outlined),
            selectedIcon: Icon(Icons.local_florist),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Metrics',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
