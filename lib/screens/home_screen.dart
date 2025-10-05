import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'today_screen.dart';
import 'calendar_screen.dart';
import 'tags_screen.dart';
import 'settings_screen.dart';
import 'add_sleep_screen.dart';
import 'add_meal_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  DateTime? _selectedDate;

  List<Widget> get _screens => [
        TodayScreen(initialDate: _selectedDate),
        CalendarScreen(
          onDateSelected: (date) {
            setState(() {
              _selectedDate = date;
              _currentIndex = 0; // Switch to Today tab
            });
          },
        ),
        const TagsScreen(),
        const SettingsScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppTheme.rhythmLightGray,
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
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.rhythmWhite,
          selectedItemColor: AppTheme.rhythmBlack,
          unselectedItemColor: AppTheme.rhythmMediumGray,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
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
              icon: Icon(Icons.local_offer_outlined),
              activeIcon: Icon(Icons.local_offer),
              label: 'Tags',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddMenu(context);
        },
        backgroundColor: AppTheme.rhythmBlack,
        foregroundColor: AppTheme.rhythmWhite,
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.rhythmWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacePulse3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMenuOption(
                  context,
                  'Sleep Entry',
                  Icons.bedtime_outlined,
                  () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddSleepScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuOption(
                  context,
                  'Meal Entry',
                  Icons.restaurant_outlined,
                  () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddMealScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuOption(
                  context,
                  'Nap Entry',
                  Icons.snooze_outlined,
                  () {
                    Navigator.pop(context);
                    // TODO: Navigate to nap entry screen
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuOption(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.rhythmBlack),
      title: Text(title),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
    );
  }
}
