import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');

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

            // Sleep Section
            _buildSectionCard(
              context,
              title: 'Sleep',
              icon: Icons.bedtime_outlined,
              onTap: () {
                // TODO: Navigate to sleep entry
              },
              child: const _PlaceholderContent(
                text: 'No sleep data for today',
              ),
            ),

            const SizedBox(height: AppTheme.spacePulse3),

            // Meals Section
            _buildSectionCard(
              context,
              title: 'Meals',
              icon: Icons.restaurant_outlined,
              onTap: () {
                // TODO: Navigate to meal entry
              },
              child: const _PlaceholderContent(
                text: 'No meals logged yet',
              ),
            ),

            const SizedBox(height: AppTheme.spacePulse3),

            // Naps Section
            _buildSectionCard(
              context,
              title: 'Naps',
              icon: Icons.snooze_outlined,
              onTap: () {
                // TODO: Navigate to nap entry
              },
              child: const _PlaceholderContent(
                text: 'No naps recorded',
              ),
            ),

            const SizedBox(height: AppTheme.spacePulse3),

            // Daily Summary
            _buildDailySummary(context),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddMenu(context);
        },
        child: const Icon(Icons.add),
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

  Widget _buildDailySummary(BuildContext context) {
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
              '0h',
              Icons.bedtime_outlined,
            ),
            const SizedBox(height: AppTheme.spacePulse2),
            _buildSummaryRow(
              context,
              'Meals',
              '0',
              Icons.restaurant_outlined,
            ),
            const SizedBox(height: AppTheme.spacePulse2),
            _buildSummaryRow(
              context,
              'Meal Cost',
              '\$0.00',
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
                    // TODO: Navigate to sleep entry screen
                  },
                ),
                _buildMenuOption(
                  context,
                  'Meal Entry',
                  Icons.restaurant_outlined,
                  () {
                    Navigator.pop(context);
                    // TODO: Navigate to meal entry screen
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
