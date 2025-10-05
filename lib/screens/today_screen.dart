import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/providers.dart';
import '../models/mood_entry.dart';
import 'add_sleep_screen.dart';
import 'add_meal_screen.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');

    // Watch sleep, meal, and mood entries for today
    final sleepEntriesAsync = ref.watch(todaySleepEntriesProvider);
    final mealEntriesAsync = ref.watch(todayMealEntriesProvider);
    final moodEntryAsync = ref.watch(todayMoodEntryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('LifeRhythm'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Text(
              dateFormat.format(now),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.rhythmMediumGray,
                  ),
            ),
            const SizedBox(height: AppTheme.spacePulse4),

            // Mood Section
            _buildMoodCard(context, ref, moodEntryAsync),

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

  Widget _buildMoodCard(BuildContext context, WidgetRef ref, AsyncValue moodEntryAsync) {
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
                    _buildMoodButton(context, ref, '😢', 'Very Bad', 1, currentMood?.moodLevel),
                    _buildMoodButton(context, ref, '😟', 'Bad', 2, currentMood?.moodLevel),
                    _buildMoodButton(context, ref, '😐', 'Okay', 3, currentMood?.moodLevel),
                    _buildMoodButton(context, ref, '😊', 'Good', 4, currentMood?.moodLevel),
                    _buildMoodButton(context, ref, '😄', 'Great', 5, currentMood?.moodLevel),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMoodButton(context, ref, '😢', 'Very Bad', 1, null),
                  _buildMoodButton(context, ref, '😟', 'Bad', 2, null),
                  _buildMoodButton(context, ref, '😐', 'Okay', 3, null),
                  _buildMoodButton(context, ref, '😊', 'Good', 4, null),
                  _buildMoodButton(context, ref, '😄', 'Great', 5, null),
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
  ) {
    final isSelected = currentMoodLevel == moodLevel;

    return InkWell(
      onTap: () async {
        // Save mood to database
        final db = ref.read(databaseProvider);
        final now = DateTime.now();
        final entry = MoodEntry(
          date: now,
          timestamp: now,
          moodLevel: moodLevel,
          emoji: emoji,
        );

        try {
          await db.createMoodEntry(entry);
          // Refresh mood data
          ref.invalidate(todayMoodEntryProvider);

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
        text: 'No sleep data for today',
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
