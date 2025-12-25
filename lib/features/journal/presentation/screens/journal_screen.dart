import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:unicons/unicons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/providers/common_providers.dart';
import '../../../sleep/data/providers/sleep_providers.dart';
import '../../../meals/data/providers/meal_providers.dart';
import '../../../exercise/data/providers/exercise_providers.dart';
import '../../../tags/data/providers/tag_providers.dart';
import '../../../../shared/models/mood_entry.dart';
import '../../../exercise/data/models/exercise_entry.dart';
import '../../../../shared/models/activity_entry.dart';
import '../../../tags/data/models/tag.dart';
import '../../../sleep/presentation/screens/add_sleep_screen.dart';
import '../../../meals/presentation/screens/add_meal_screen.dart';
import '../../../exercise/presentation/screens/add_exercise_screen.dart';
import '../../../tags/presentation/screens/tags_screen.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key, this.initialDate, this.onTodayPressed, this.onDateChanged});

  final DateTime? initialDate;
  final VoidCallback? onTodayPressed;
  final Function(DateTime?)? onDateChanged;

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
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
    widget.onTodayPressed?.call();
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
        title: const Text('DailyRhythm'),
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
            // Notify parent about date change
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            if (newDate == today) {
              widget.onDateChanged?.call(null);
            } else {
              widget.onDateChanged?.call(newDate);
            }
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
    final exerciseEntriesAsync = ref.watch(exerciseEntriesProvider(normalizedDate));
    final taskEntriesAsync = ref.watch(taskEntriesProvider(normalizedDate));
    final activityEntriesAsync = ref.watch(activityEntriesProvider(normalizedDate));
    final allTagsAsync = ref.watch(allTagsProvider);

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
                        date: date,
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
                    builder: (context) => AddSleepScreen(date: date),
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
                    builder: (context) => AddSleepScreen(date: date),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacePulse2),
                child: Text(
                  'Error loading sleep data',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.rhythmMediumGray,
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
                        color: AppTheme.rhythmMediumGray,
                      ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacePulse3),

          // Exercise Section
          exerciseEntriesAsync.when(
            data: (entries) {
              return _buildSectionCard(
                context,
                title: 'Exercise',
                icon: Icons.fitness_center_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddExerciseScreen(),
                    ),
                  );
                },
                child: _buildExerciseContent(context, entries),
              );
            },
            loading: () => _buildSectionCard(
              context,
              title: 'Exercise',
              icon: Icons.fitness_center_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddExerciseScreen(),
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
              title: 'Exercise',
              icon: Icons.fitness_center_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddExerciseScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacePulse2),
                child: Text(
                  'Error loading exercises',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.rhythmMediumGray,
                      ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacePulse3),

          // Activities Section
          activityEntriesAsync.when(
            data: (entries) {
              return _buildActivitiesCard(context, ref, entries, date);
            },
            loading: () => _buildActivitiesCard(context, ref, const [], date),
            error: (error, stack) => _buildActivitiesCard(context, ref, const [], date),
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
                    _buildMoodButton(context, ref, UniconsLine.sad_crying, 'Very Bad', 1, currentMood?.moodLevel, date),
                    _buildMoodButton(context, ref, UniconsLine.frown, 'Bad', 2, currentMood?.moodLevel, date),
                    _buildMoodButton(context, ref, UniconsLine.meh, 'Okay', 3, currentMood?.moodLevel, date),
                    _buildMoodButton(context, ref, UniconsLine.smile, 'Good', 4, currentMood?.moodLevel, date),
                    _buildMoodButton(context, ref, UniconsLine.grin, 'Great', 5, currentMood?.moodLevel, date),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMoodButton(context, ref, UniconsLine.sad_crying, 'Very Bad', 1, null, date),
                  _buildMoodButton(context, ref, UniconsLine.frown, 'Bad', 2, null, date),
                  _buildMoodButton(context, ref, UniconsLine.meh, 'Okay', 3, null, date),
                  _buildMoodButton(context, ref, UniconsLine.smile, 'Good', 4, null, date),
                  _buildMoodButton(context, ref, UniconsLine.grin, 'Great', 5, null, date),
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
    IconData icon,
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
          emoji: label, // Store the label as emoji for backwards compatibility
        );

        try {
          await db.upsertMoodEntry(entry);
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
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppTheme.rhythmBlack : AppTheme.rhythmMediumGray,
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

  String _getSleepHoursDisplay(dynamic entry) {
    // If totalHours is calculated and saved, use it
    if (entry.totalHours != null) {
      return '${entry.totalHours!.toStringAsFixed(1)}h';
    }

    // Otherwise show unknown (can't calculate without previous day's data)
    return 'unknown';
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
                'Total: ${_getSleepHoursDisplay(entry)}',
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
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddMealScreen(entry: entry),
                  ),
                );
              },
              child: Padding(
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

  Widget _buildExerciseContent(BuildContext context, List<ExerciseEntry> entries) {
    if (entries.isEmpty) {
      return const _PlaceholderContent(
        text: 'No exercises',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((entry) {
        Widget content;
        if (entry.type == ExerciseType.run) {
          if (entry.runType == RunType.interval) {
            content = Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Interval Run',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  '${entry.intervalCount}x ${entry.distance}km',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            );
          } else {
            content = Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Run',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  '${entry.distance}km',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            );
          }
        } else {
          // Weight lifting
          content = Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                entry.exerciseName ?? 'Weight Lifting',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Text(
                '${entry.sets}x${entry.reps} @ ${entry.weight}kg',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );
        }

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddExerciseScreen(entry: entry),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacePulse1),
            child: content,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActivitiesCard(BuildContext context, WidgetRef ref, List<ActivityEntry> entries, DateTime date) {
    final allTagsAsync = ref.watch(allTagsProvider);
    final selectedTagIds = entries.map((e) => e.tagId).toSet();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_activity_outlined, size: 20),
                    const SizedBox(width: AppTheme.spacePulse2),
                    Text(
                      'Activities',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit tags',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TagsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacePulse3),
            allTagsAsync.when(
              data: (tags) {
                if (tags.isEmpty) {
                  return Center(
                    child: Text(
                      'No tags yet. Tap + to create one.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.rhythmMediumGray,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                // Group tags by category
                final groupedTags = <String, List<Tag>>{};
                for (final tag in tags) {
                  if (!groupedTags.containsKey(tag.category)) {
                    groupedTags[tag.category] = [];
                  }
                  groupedTags[tag.category]!.add(tag);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: groupedTags.entries.map((entry) {
                    final category = entry.key;
                    final categoryTags = entry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (groupedTags.keys.first != category)
                          const SizedBox(height: AppTheme.spacePulse3),
                        Text(
                          category,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.rhythmMediumGray,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: AppTheme.spacePulse2),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const int columns = 5;
                            final double spacing = AppTheme.spacePulse3.toDouble();
                            final double totalSpacing = spacing * (columns - 1);
                            final double itemWidth = (constraints.maxWidth - totalSpacing) / columns;

                            // Split tags into rows of 5
                            final rows = <List<Tag>>[];
                            for (var i = 0; i < categoryTags.length; i += columns) {
                              rows.add(categoryTags.sublist(
                                i,
                                i + columns > categoryTags.length ? categoryTags.length : i + columns,
                              ));
                            }

                            return Column(
                              children: rows.map((rowTags) {
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: rows.last == rowTags ? 0 : spacing,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: rowTags.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final tag = entry.value;
                                      final isSelected = selectedTagIds.contains(tag.id);

                                      return Padding(
                                        padding: EdgeInsets.only(
                                          right: index < rowTags.length - 1 ? spacing : 0,
                                        ),
                                        child: SizedBox(
                                          width: itemWidth,
                                          child: InkWell(
                                            onTap: () async {
                                              if (isSelected) {
                                                final activityToRemove = entries.firstWhere((e) => e.tagId == tag.id);
                                                if (activityToRemove.id != null) {
                                                  final db = ref.read(databaseProvider);
                                                  await db.deleteActivityEntry(activityToRemove.id!);
                                                  final normalizedDate = DateTime(date.year, date.month, date.day);
                                                  ref.invalidate(activityEntriesProvider(normalizedDate));
                                                }
                                              } else {
                                                final db = ref.read(databaseProvider);
                                                final normalizedDate = DateTime(date.year, date.month, date.day);
                                                final entry = ActivityEntry(
                                                  date: normalizedDate,
                                                  timestamp: DateTime.now(),
                                                  tagId: tag.id!,
                                                );
                                                await db.createActivityEntry(entry);
                                                ref.invalidate(activityEntriesProvider(normalizedDate));
                                              }
                                            },
                                            child: Align(
                                              alignment: Alignment.topCenter,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? AppTheme.rhythmBlack
                                                          : AppTheme.rhythmLightGray.withOpacity(0.3),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Center(
                                                      child: Icon(
                                                        _getUniconFromName(tag.emoji),
                                                        size: 20,
                                                        color: isSelected
                                                            ? AppTheme.rhythmWhite
                                                            : AppTheme.rhythmBlack,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: AppTheme.spacePulse1),
                                                  SizedBox(
                                                    width: 52,
                                                    height: 24,
                                                    child: Text(
                                                      tag.name,
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                            fontSize: 8,
                                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                          ),
                                                      textAlign: TextAlign.center,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Text(
                  'Error loading tags',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.rhythmMediumGray,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getUniconFromName(String iconName) {
    // Map icon names to Unicons (using simpler icon names that definitely exist)
    final iconMap = <String, IconData>{
      'sick': UniconsLine.frown,
      'annoyed': UniconsLine.meh,
      'virus_slash': UniconsLine.shield,
      'tear': UniconsLine.tear,
      'ban': UniconsLine.ban,
      'arrow_up': UniconsLine.arrow_up,
      'exclamation_triangle': UniconsLine.exclamation_triangle,
      'user_arrows': UniconsLine.arrow_circle_up,
      'dumbbell': UniconsLine.dumbbell,
      'head_side': UniconsLine.head_side,
      'head_side_cough': UniconsLine.head_side_cough,
      'hospital': UniconsLine.hospital,
      'sad': UniconsLine.sad,
      'moon': UniconsLine.moon,
      'clinic_medical': UniconsLine.clinic_medical,
      'temperature': UniconsLine.temperature,
      'book': UniconsLine.book,
      'graduation_cap': UniconsLine.graduation_cap,
      'file_alt': UniconsLine.file_alt,
      'briefcase': UniconsLine.briefcase,
      'play_circle': UniconsLine.play_circle,
      'game_structure': UniconsLine.game_structure,
      'brush_alt': UniconsLine.brush_alt,
      'glass_martini': UniconsLine.glass_martini,
      'home': UniconsLine.home,
      'bed': UniconsLine.bed,
      'scissors': UniconsLine.edit_alt,
    };

    return iconMap[iconName] ?? UniconsLine.question_circle;
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
