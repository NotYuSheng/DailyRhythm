import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/metric_data.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../../data/providers/metrics_providers.dart';
import '../widgets/quick_stat_card.dart';

class MetricsScreen extends ConsumerStatefulWidget {
  const MetricsScreen({super.key});

  @override
  ConsumerState<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends ConsumerState<MetricsScreen> {
  int _selectedRangeIndex = 0;

  final List<DateRange> _dateRanges = [
    DateRange.last7Days(),
    DateRange.last30Days(),
    DateRange.thisMonth(),
    DateRange.thisYear(),
    DateRange.allTime(),
  ];

  DateRange get _selectedRange => _dateRanges[_selectedRangeIndex];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: const Text(
          'Metrics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time Range Selector
            _buildTimeRangeSelector(isDark),
            const SizedBox(height: AppTheme.spacePulse4),

            // Quick Stats Cards
            _buildQuickStats(),
            const SizedBox(height: AppTheme.spacePulse4),

            // Sleep Chart
            _buildSleepChart(),
            const SizedBox(height: AppTheme.spacePulse3),

            // Mood Chart
            _buildMoodChart(),
            const SizedBox(height: AppTheme.spacePulse3),

            // Activity Breakdown
            _buildActivityBreakdown(),
            const SizedBox(height: AppTheme.spacePulse4),

            // Insights
            _buildInsights(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector(bool isDark) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _dateRanges.length,
        itemBuilder: (context, index) {
          final theme = Theme.of(context);
          final isSelected = index == _selectedRangeIndex;
          final range = _dateRanges[index];

          return Padding(
            padding: EdgeInsets.only(
              right: index < _dateRanges.length - 1 ? AppTheme.spacePulse2 : 0,
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedRangeIndex = index;
                });
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacePulse3,
                  vertical: AppTheme.spacePulse2,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    range.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickStats() {
    final sleepAsync = ref.watch(sleepMetricsProvider(_selectedRange));
    final moodAsync = ref.watch(moodMetricsProvider(_selectedRange));
    final exerciseAsync = ref.watch(exerciseMetricsProvider(_selectedRange));
    final activityAsync = ref.watch(activityMetricsProvider(_selectedRange));

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: sleepAsync.when(
                data: (metrics) => QuickStatCard(
                  icon: Icons.bedtime_outlined,
                  label: 'Avg Sleep',
                  value: '${metrics.averageHours.toStringAsFixed(1)}h',
                  trend: _calculateTrend(metrics.averageHours, metrics.previousAverageHours),
                  trendPercentage: _calculateTrendPercentage(metrics.averageHours, metrics.previousAverageHours),
                ),
                loading: () => _buildLoadingCard(),
                error: (_, __) => _buildErrorCard('Sleep'),
              ),
            ),
            const SizedBox(width: AppTheme.spacePulse2),
            Expanded(
              child: moodAsync.when(
                data: (metrics) => QuickStatCard(
                  icon: Icons.sentiment_satisfied_alt_outlined,
                  label: 'Avg Mood',
                  value: metrics.averageMood > 0 ? metrics.averageMood.toStringAsFixed(1) : 'N/A',
                  trend: _calculateTrend(metrics.averageMood, metrics.previousAverageMood),
                  trendPercentage: _calculateTrendPercentage(metrics.averageMood, metrics.previousAverageMood),
                ),
                loading: () => _buildLoadingCard(),
                error: (_, __) => _buildErrorCard('Mood'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacePulse2),
        Row(
          children: [
            Expanded(
              child: exerciseAsync.when(
                data: (metrics) => QuickStatCard(
                  icon: Icons.fitness_center_outlined,
                  label: 'Exercises',
                  value: '${metrics.totalExercises}',
                  trend: _calculateTrend(
                    metrics.totalExercises.toDouble(),
                    metrics.previousTotalExercises?.toDouble(),
                  ),
                  trendPercentage: _calculateTrendPercentage(
                    metrics.totalExercises.toDouble(),
                    metrics.previousTotalExercises?.toDouble(),
                  ),
                ),
                loading: () => _buildLoadingCard(),
                error: (_, __) => _buildErrorCard('Exercise'),
              ),
            ),
            const SizedBox(width: AppTheme.spacePulse2),
            Expanded(
              child: activityAsync.when(
                data: (metrics) => QuickStatCard(
                  icon: Icons.local_activity_outlined,
                  label: 'Activities',
                  value: '${metrics.totalActivities}',
                  trend: _calculateTrend(
                    metrics.totalActivities.toDouble(),
                    metrics.previousTotalActivities?.toDouble(),
                  ),
                  trendPercentage: _calculateTrendPercentage(
                    metrics.totalActivities.toDouble(),
                    metrics.previousTotalActivities?.toDouble(),
                  ),
                ),
                loading: () => _buildLoadingCard(),
                error: (_, __) => _buildErrorCard('Activities'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSleepChart() {
    final sleepAsync = ref.watch(sleepMetricsProvider(_selectedRange));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bedtime_outlined, size: 20),
                const SizedBox(width: AppTheme.spacePulse2),
                Text(
                  'Sleep Pattern',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacePulse3),
            sleepAsync.when(
              data: (metrics) {
                if (metrics.dailyData.isEmpty) {
                  return _buildEmptyState('No sleep data for this period');
                }
                return SizedBox(
                  height: 200,
                  child: _buildSleepLineChart(metrics),
                );
              },
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => _buildEmptyState('Error loading sleep data'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepLineChart(SleepMetrics metrics) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final spots = metrics.dailyData
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.value))
        .toList();

    if (spots.isEmpty) {
      return _buildEmptyState('No data available');
    }

    // Calculate max Y value based on data, with a minimum of 12
    final maxDataValue = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    final maxY = (maxDataValue > 12 ? (maxDataValue + 2).ceilToDouble() : 12.0);
    final interval = maxY > 12 ? (maxY / 6).ceilToDouble() : 2.0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppTheme.getChartGridColor(context),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: metrics.dailyData.length > 7 ? (metrics.dailyData.length / 5).ceilToDouble() : 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < metrics.dailyData.length) {
                  final date = metrics.dailyData[value.toInt()].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('M/d').format(date),
                      style: TextStyle(
                        color: AppTheme.getSubtleTextColor(context),
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: interval,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}h',
                  style: TextStyle(
                    color: AppTheme.getSubtleTextColor(context),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (metrics.dailyData.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.getChartLineColor(context),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: AppTheme.getChartLineColor(context),
                  strokeWidth: 0,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.getChartLineColor(context).withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodChart() {
    final moodAsync = ref.watch(moodMetricsProvider(_selectedRange));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sentiment_satisfied_alt_outlined, size: 20),
                const SizedBox(width: AppTheme.spacePulse2),
                Text(
                  'Mood Distribution',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacePulse3),
            moodAsync.when(
              data: (metrics) {
                if (metrics.dailyData.isEmpty) {
                  return _buildEmptyState('No mood data for this period');
                }

                final total = metrics.distribution.values.fold<int>(0, (sum, count) => sum + count);
                if (total == 0) {
                  return _buildEmptyState('No mood data for this period');
                }

                return Column(
                  children: [
                    _buildMoodBar(context, '😄 Great (5)', metrics.distribution[5] ?? 0, total, isDark),
                    const SizedBox(height: AppTheme.spacePulse2),
                    _buildMoodBar(context, '😊 Good (4)', metrics.distribution[4] ?? 0, total, isDark),
                    const SizedBox(height: AppTheme.spacePulse2),
                    _buildMoodBar(context, '😐 Okay (3)', metrics.distribution[3] ?? 0, total, isDark),
                    const SizedBox(height: AppTheme.spacePulse2),
                    _buildMoodBar(context, '😟 Bad (2)', metrics.distribution[2] ?? 0, total, isDark),
                    const SizedBox(height: AppTheme.spacePulse2),
                    _buildMoodBar(context, '😢 Very Bad (1)', metrics.distribution[1] ?? 0, total, isDark),
                  ],
                );
              },
              loading: () => const SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => _buildEmptyState('Error loading mood data'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodBar(BuildContext context, String label, int count, int total, bool isDark) {
    final theme = Theme.of(context);
    final percentage = total > 0 ? (count / total) * 100 : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.getSubtleTextColor(context),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacePulse2),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage / 100,
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppTheme.spacePulse2),
        SizedBox(
          width: 45,
          child: Text(
            '${percentage.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityBreakdown() {
    final activityAsync = ref.watch(activityMetricsProvider(_selectedRange));
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_activity_outlined, size: 20),
                const SizedBox(width: AppTheme.spacePulse2),
                Text(
                  'Top Activities',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacePulse3),
            activityAsync.when(
              data: (metrics) {
                if (metrics.topActivities.isEmpty) {
                  return _buildEmptyState('No activities logged for this period');
                }

                final topFive = metrics.topActivities.take(5).toList();
                return Column(
                  children: topFive.map((activity) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spacePulse2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              activity.tagName,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            '${activity.count}x',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacePulse2),
                          Text(
                            '${activity.percentage.toStringAsFixed(0)}%',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _buildEmptyState('Error loading activity data'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsights() {
    final insightsAsync = ref.watch(metricsInsightsProvider(_selectedRange));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outlined, size: 20),
                const SizedBox(width: AppTheme.spacePulse2),
                Text(
                  'Insights',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacePulse3),
            insightsAsync.when(
              data: (insights) {
                if (insights.isEmpty) {
                  return _buildEmptyState('Not enough data to generate insights yet');
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: insights.map((insight) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spacePulse2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _getInsightIcon(insight.type),
                            size: 16,
                            color: AppTheme.getSubtleTextColor(context),
                          ),
                          const SizedBox(width: AppTheme.spacePulse2),
                          Expanded(
                            child: Text(
                              insight.text,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _buildEmptyState('Error generating insights'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getInsightIcon(InsightType type) {
    switch (type) {
      case InsightType.positive:
        return Icons.trending_up;
      case InsightType.negative:
        return Icons.trending_down;
      case InsightType.correlation:
        return Icons.insights;
      case InsightType.neutral:
        return Icons.info_outline;
    }
  }

  Widget _buildLoadingCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacePulse3),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String label) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        child: Center(
          child: Text(
            'Error loading $label',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.grey600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.grey600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  TrendDirection _calculateTrend(double current, double? previous) {
    if (previous == null || previous == 0) return TrendDirection.neutral;

    final diff = current - previous;
    final percentChange = (diff / previous).abs();

    if (percentChange < 0.05) return TrendDirection.neutral;
    if (diff > 0) return TrendDirection.up;
    return TrendDirection.down;
  }

  double _calculateTrendPercentage(double current, double? previous) {
    if (previous == null || previous == 0) return 0.0;
    return ((current - previous) / previous) * 100;
  }
}
