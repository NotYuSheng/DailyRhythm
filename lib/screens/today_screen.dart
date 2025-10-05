import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/providers.dart';
import '../models/mood_entry.dart';
import 'add_sleep_screen.dart';
import 'add_meal_screen.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late DateTime _selectedDate;
  late PageController _pageController;
  static const int _centerPage = 10000;

  @override
  void initState() {
    super.initState();
    final initialDate = widget.initialDate ?? DateTime.now();
    _selectedDate = DateTime(initialDate.year, initialDate.month, initialDate.day);

    // Calculate initial page based on selected date
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    final daysDifference = _selectedDate.difference(todayNormalized).inDays;
    _pageController = PageController(initialPage: _centerPage + daysDifference);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _getDateForPage(int page) {
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    final daysDifference = page - _centerPage;
    return todayNormalized.add(Duration(days: daysDifference));
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    final dateNormalized = DateTime(date.year, date.month, date.day);
    final todayNormalized = DateTime(now.year, now.month, now.day);
    return dateNormalized == todayNormalized;
  }

  bool _isFuture(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateNormalized = DateTime(date.year, date.month, date.day);
    return dateNormalized.isAfter(today);
  }

  void _goToToday() {
    _pageController.animateToPage(
      _centerPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LifeRhythm'),
        actions: [
          if (!_isToday(_selectedDate))
            TextButton(
              onPressed: _goToToday,
              child: const Text('Today'),
            ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (page) {
          final newDate = _getDateForPage(page);
          // Prevent navigation to future dates
          if (_isFuture(newDate)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _pageController.jumpToPage(page - 1);
            });
          } else {
            setState(() {
              _selectedDate = newDate;
            });
          }
        },
        itemBuilder: (context, page) {
          final date = _getDateForPage(page);

          // Don't render future pages
          if (_isFuture(date)) {
            return const SizedBox.shrink();
          }

          return _buildDayContent(context, date);
        },
      ),
    );
  }

  Widget _buildDayContent(BuildContext context, DateTime date) {
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');

    // Normalize the date to start of day for consistent querying
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // Watch entries for the selected date
    final sleepEntriesAsync = ref.watch(sleepEntriesProvider(normalizedDate));
    final mealEntriesAsync = ref.watch(mealEntriesProvider(normalizedDate));
    final moodEntryAsync = ref.watch(moodEntryProvider(normalizedDate));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacePulse3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Header with Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _isToday(date) ? 'Today - ${dateFormat.format(date)}' : dateFormat.format(date),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.rhythmMediumGray,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: _isFuture(date.add(const Duration(days: 1)))
                      ? AppTheme.rhythmLightGray
                      : null,
                ),
                onPressed: _isFuture(date.add(const Duration(days: 1)))
                    ? null
                    : () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacePulse4),

          // Mood Section
          _buildMoodCard(context, ref, moodEntryAsync, date),

          const SizedBox(height: AppTheme.spacePulse3),

          // Sleep Section
          sleepEntriesAsync.when(
            data: (entries) {
              return _buildSectionCard(
                context,
                title: 'Sleep',
                icon: Icons.bedtime_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddSleepScreen(
                        entry: entries.isNotEmpty ? entries.first : null,
                      ),
                    ),
                  );
                },
                child: _buildSleepContent(context, entries),
              );
            },
            loading: () => _buildSectionCard(
              context,
              title: 'Sleep',
              icon: Icons.bedtime_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddSleepScreen(),
                  ),
                );
              },
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacePulse3),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (error, stack) => _buildSectionCard(
              context,
              title: 'Sleep',
              icon: Icons.bedtime_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddSleepScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacePulse2),
                child: Text(
                  'Error loading sleep data',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                      ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacePulse3),

          // Meals Section
          mealEntriesAsync.when(
            data: (entries) {
              return _buildSectionCard(
                context,
                title: 'Meals',
                icon: Icons.restaurant_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddMealScreen(),
                    ),
                  );
                },
                child: _buildMealContent(context, entries),
              );
            },
            loading: () => _buildSectionCard(
              context,
              title: 'Meals',
              icon: Icons.restaurant_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddMealScreen(),
                  ),
                );
              },
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacePulse3),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (error, stack) => _buildSectionCard(
              context,
              title: 'Meals',
              icon: Icons.restaurant_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddMealScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacePulse2),
                child: Text(
                  'Error loading meals',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                      ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacePulse3),

          // Daily Summary
          _buildDailySummary(context, sleepEntriesAsync, mealEntriesAsync),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacePulse3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: AppTheme.rhythmBlack),
                  const SizedBox(width: AppTheme.spacePulse2),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppTheme.rhythmMediumGray,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacePulse3),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodCard(BuildContext context, WidgetRef ref, AsyncValue moodEntryAsync, DateTime date) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sentiment_satisfied_alt_outlined, size: 20, color: AppTheme.rhythmBlack),
                const SizedBox(width: AppTheme.spacePulse2),
                Text(
                  'Mood',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacePulse3),
            moodEntryAsync.when(
              data: (currentMood) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMoodButton(context, ref, '😢', 'Very Bad', 1, currentMood?.moodLevel, date),
                    _buildMoodButton(context, ref, '😟', 'Bad', 2, currentMood?.moodLevel, date),
                    _buildMoodButton(context, ref, '😐', 'Okay', 3, currentMood?.moodLevel, date),
                    _buildMoodButton(context, ref, '😊', 'Good', 4, currentMood?.moodLevel, date),
                    _buildMoodButton(context, ref, '😄', 'Great', 5, currentMood?.moodLevel, date),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMoodButton(context, ref, '😢', 'Very Bad', 1, null, date),
                  _buildMoodButton(context, ref, '😟', 'Bad', 2, null, date),
                  _buildMoodButton(context, ref, '😐', 'Okay', 3, null, date),
                  _buildMoodButton(context, ref, '😊', 'Good', 4, null, date),
                  _buildMoodButton(context, ref, '😄', 'Great', 5, null, date),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodButton(
    BuildContext context,
    WidgetRef ref,
    String emoji,
    String label,
    int moodLevel,
    int? currentMoodLevel,
    DateTime date,
  ) {
    final isSelected = currentMoodLevel == moodLevel;

    return InkWell(
      onTap: () async {
        // Save mood to database
        final db = ref.read(databaseProvider);
        final normalizedDate = DateTime(date.year, date.month, date.day);
        final entry = MoodEntry(
          date: normalizedDate,
          timestamp: DateTime.now(),
          moodLevel: moodLevel,
          emoji: emoji,
        );

        try {
          await db.createMoodEntry(entry);
          // Refresh mood data for this date
          ref.invalidate(moodEntryProvider(normalizedDate));

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Mood saved: $label'),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error saving mood: $e'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacePulse2),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.rhythmBlack.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: isSelected ? Border.all(color: AppTheme.rhythmBlack, width: 2) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: TextStyle(
                fontSize: 32,
                color: isSelected ? AppTheme.rhythmBlack : null,
              ),
            ),
            const SizedBox(height: AppTheme.spacePulse1),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected ? AppTheme.rhythmBlack : AppTheme.rhythmMediumGray,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepContent(BuildContext context, List entries) {
    if (entries.isEmpty) {
      return const _PlaceholderContent(
        text: 'No sleep data',
      );
    }
    final entry = entries.first;
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacePulse2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Wake: ${entry.wakeUpTime != null ? DateFormat('h:mm a').format(entry.wakeUpTime!) : 'N/A'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                'Sleep: ${entry.sleepTime != null ? DateFormat('h:mm a').format(entry.sleepTime!) : 'N/A'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacePulse2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ${entry.totalHours?.toStringAsFixed(1) ?? entry.calculatedHours.toStringAsFixed(1)}h',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (entry.napHours != null && entry.napHours! > 0)
                Text(
                  'Nap: ${entry.napHours!.toStringAsFixed(1)}h',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.rhythmMediumGray,
                      ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealContent(BuildContext context, List entries) {
    if (entries.isEmpty) {
      return const _PlaceholderContent(
        text: 'No meals logged yet',
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacePulse2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacePulse2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.quantity > 1 ? '${entry.quantity}x ${entry.name}' : entry.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (entry.tags.isNotEmpty)
                          Text(
                            entry.tags.join(', '),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.rhythmMediumGray,
                                ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${entry.price.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        DateFormat('h:mm a').format(entry.time),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.rhythmMediumGray,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '\$${entries.fold<double>(0.0, (sum, entry) => sum + entry.price).toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummary(BuildContext context, AsyncValue sleepEntriesAsync, AsyncValue mealEntriesAsync) {
    // Calculate total sleep hours (including naps)
    final totalSleepHours = sleepEntriesAsync.when(
      data: (entries) {
        if (entries.isEmpty) return '0h';
        double total = 0.0;
        for (final entry in entries) {
          // Add main sleep hours
          total += entry.totalHours ?? entry.calculatedHours;
          // Add nap hours if available
          if (entry.napHours != null) {
            total += entry.napHours!;
          }
        }
        return '${total.toStringAsFixed(1)}h';
      },
      loading: () => '...',
      error: (_, __) => 'N/A',
    );

    // Calculate meal cost
    final mealCost = mealEntriesAsync.when(
      data: (entries) {
        if (entries.isEmpty) return '\$0.00';
        double total = 0.0;
        for (final entry in entries) {
          total += entry.price;
        }
        return '\$${total.toStringAsFixed(2)}';
      },
      loading: () => '...',
      error: (_, __) => 'N/A',
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacePulse3),
            _buildSummaryRow(
              context,
              'Total Sleep',
              totalSleepHours,
              Icons.bedtime_outlined,
            ),
            const SizedBox(height: AppTheme.spacePulse2),
            _buildSummaryRow(
              context,
              'Meal Cost',
              mealCost,
              Icons.attach_money_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.rhythmMediumGray),
        const SizedBox(width: AppTheme.spacePulse2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _PlaceholderContent extends StatelessWidget {
  final String text;

  const _PlaceholderContent({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.rhythmLightGray,
              ),
        ),
      ),
    );
  }
}
