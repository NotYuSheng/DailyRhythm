import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/metric_data.dart';

class QuickStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TrendDirection trend;
  final double trendPercentage;
  final VoidCallback? onTap;

  const QuickStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.trend,
    required this.trendPercentage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacePulse3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: isDark ? AppTheme.rhythmWhite : AppTheme.rhythmBlack,
                  ),
                  _buildTrendIndicator(isDark),
                ],
              ),
              const SizedBox(height: AppTheme.spacePulse2),
              Text(
                value,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacePulse1),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.rhythmMediumGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendIndicator(bool isDark) {
    if (trend == TrendDirection.neutral || trendPercentage.abs() < 0.1) {
      return const SizedBox.shrink();
    }

    final isPositive = trend == TrendDirection.up;
    final icon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;
    final color = isDark
        ? (isPositive ? AppTheme.rhythmWhite : AppTheme.rhythmLightGray)
        : (isPositive ? AppTheme.rhythmBlack : AppTheme.rhythmMediumGray);

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(
          '${trendPercentage.abs().toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
