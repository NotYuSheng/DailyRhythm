# LifeRhythm - Next Development Steps

## 🎯 Immediate Next Task: Sleep Entry Screen

Let's build the first functional feature - sleep tracking.

### Step 1: Create Riverpod Providers

Create `lib/services/providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_service.dart';
import '../models/sleep_entry.dart';
import '../models/meal_entry.dart';
import '../models/nap_entry.dart';

// Database provider
final databaseProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

// Sleep entries for today
final todaySleepEntriesProvider = FutureProvider<List<SleepEntry>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getSleepEntriesByDate(DateTime.now());
});

// Meal entries for today
final todayMealEntriesProvider = FutureProvider<List<MealEntry>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getMealEntriesByDate(DateTime.now());
});

// Nap entries for today
final todayNapEntriesProvider = FutureProvider<List<NapEntry>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getNapEntriesByDate(DateTime.now());
});
```

### Step 2: Create Sleep Entry Screen

Create `lib/screens/add_sleep_screen.dart`:

```dart
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

  @override
  void initState() {
    super.initState();
    _date = widget.entry?.date ?? DateTime.now();
    _sleepTime = widget.entry?.sleepTime;
    _wakeUpTime = widget.entry?.wakeUpTime;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'Add Sleep' : 'Edit Sleep'),
        actions: [
          TextButton(
            onPressed: _saveSleep,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        children: [
          // Sleep Time
          _buildTimePicker(
            label: 'Sleep Time',
            time: _sleepTime,
            onSelect: (time) => setState(() => _sleepTime = time),
          ),
          const SizedBox(height: AppTheme.spacePulse3),

          // Wake Up Time
          _buildTimePicker(
            label: 'Wake Up Time',
            time: _wakeUpTime,
            onSelect: (time) => setState(() => _wakeUpTime = time),
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
    final duration = _wakeUpTime!.difference(_sleepTime!);
    return duration.inMinutes / 60.0;
  }

  Future<void> _saveSleep() async {
    if (_sleepTime == null || _wakeUpTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set both sleep and wake times')),
      );
      return;
    }

    final entry = SleepEntry(
      id: widget.entry?.id,
      date: _date,
      sleepTime: _sleepTime,
      wakeUpTime: _wakeUpTime,
      totalHours: _calculateHours(),
    );

    final db = ref.read(databaseProvider);
    if (widget.entry == null) {
      await db.createSleepEntry(entry);
    } else {
      await db.updateSleepEntry(entry);
    }

    // Refresh today's entries
    ref.invalidate(todaySleepEntriesProvider);

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
```

### Step 3: Update Today Screen to Show Real Data

Update `lib/screens/today_screen.dart`:

1. Convert to `ConsumerWidget`
2. Use `ref.watch(todaySleepEntriesProvider)` to load data
3. Display entries in the cards
4. Navigate to `AddSleepScreen` when tapped

### Step 4: Wire Up Navigation

Update the FAB menu in `today_screen.dart` to navigate to `AddSleepScreen`:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const AddSleepScreen(),
  ),
);
```

---

## 🎨 UI Polish Ideas

### Wave Visualization (Future Enhancement)
- Add subtle wave animations
- Visualize sleep patterns as waves
- Rhythmic loading indicators

### Gestures
- Swipe to delete entries (use `flutter_slidable`)
- Pull to refresh
- Long press for quick actions

### Empty States
- Beautiful empty state illustrations
- Encouraging messages
- Quick action buttons

---

## 🔄 Development Workflow

1. **Build feature** → Test locally
2. **Commit changes** → Git (when ready)
3. **Test on device** → Android/iOS
4. **Iterate** → Improve UX

---

## 📱 Testing Checklist

Before moving to next feature:
- ✅ Can add sleep entry
- ✅ Can edit sleep entry
- ✅ Can delete sleep entry
- ✅ Entry shows on Today screen
- ✅ Daily summary updates
- ✅ Data persists after app restart

---

## 🚀 Quick Commands

```bash
# Run app
flutter run

# Hot reload (in running app)
Press 'r'

# Hot restart (in running app)
Press 'R'

# Check for errors
flutter analyze

# Run tests
flutter test

# Clean build
flutter clean && flutter pub get
```

---

## 💡 Development Tips

1. **Use Hot Reload**: Most UI changes reflect instantly with 'r'
2. **Check Flutter DevTools**: Inspect UI, debug performance
3. **Test on Real Device**: Emulators can be slow
4. **Follow Material Design**: Use built-in widgets when possible
5. **Keep It Simple**: Build MVP first, polish later

---

## 🎯 After Sleep Entry Works

Next features to build (in order):
1. Meal Entry Screen
2. Nap Entry Screen
3. History Screen (calendar view)
4. Tag Creation
5. Tag Assignment
6. Excel Export
7. Google Drive Backup

Good luck! 🚀
