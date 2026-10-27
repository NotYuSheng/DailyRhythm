import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/metric_data.dart';
import '../../data/providers/metrics_providers.dart';
import '../../../garden/presentation/garden_style.dart';
import '../widgets/day_ratings_section.dart';
import '../widgets/fun_facts_section.dart';
import '../widgets/quick_stat_card.dart';

class MetricsScreen extends ConsumerStatefulWidget {
  const MetricsScreen({super.key});

  @override
  ConsumerState<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends ConsumerState<MetricsScreen> {
  _Period _period = _Period.month;

  /// Any day in the period shown; arrows move it back and forward.
  DateTime _anchor = DateTime.now();

  DateRange get _selectedRange => switch (_period) {
        _Period.week => DateRange.week(_anchor),
        _Period.month => DateRange.month(_anchor),
        _Period.year => DateRange.year(_anchor),
        _Period.all => DateRange.allTime(),
      };

  void _step(int delta) => setState(() {
        _anchor = switch (_period) {
          _Period.week => DateTime(_anchor.year, _anchor.month, _anchor.day + 7 * delta),
          _Period.month => DateTime(_anchor.year, _anchor.month + delta),
          _Period.year => DateTime(_anchor.year + delta),
          _Period.all => _anchor,
        };
      });

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);

    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(
        backgroundColor: colors.ground,
        elevation: 0,
        title: Text('Metrics', style: nunito(20, FontWeight.w900, colors.ink)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time Range Selector
            _buildTimeRangeSelector(),
            const SizedBox(height: AppTheme.spacePulse4),

            FunFactsSection(range: _selectedRange),
            const SizedBox(height: AppTheme.spacePulse4),

            // Quick Stats Cards
            _buildQuickStats(),
            const SizedBox(height: AppTheme.spacePulse4),

            // Sleep Chart
            _buildSleepChart(),
            const SizedBox(height: AppTheme.spacePulse3),

            // Mood, energy, stress and focus; tag comparisons; watch
            DayRatingsSection(range: _selectedRange),
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

  Widget _buildTimeRangeSelector() {
    final colors = GardenColors.of(context);
    final range = _selectedRange;
    final today = DateTime.now();
    final first = ref.watch(firstLoggedDayProvider).value;
    final canGoBack = first != null && range.start.isAfter(first);
    final canGoForward = range.end.isBefore(DateTime(today.year, today.month, today.day));
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<_Period>(
            showSelectedIcon: false,
            segments: [
              for (final p in _Period.values)
                ButtonSegment<_Period>(
                  value: p,
                  // Shrinks at large text sizes rather than overflowing.
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(p.label, maxLines: 1, softWrap: false)),
                ),
            ],
            selected: {_period},
            // Each kind opens on the period holding today.
            onSelectionChanged: (selection) => setState(() {
              _period = selection.first;
              _anchor = DateTime.now();
            }),
          ),
        ),
        if (_period != _Period.all) ...[
          const SizedBox(height: AppTheme.spacePulse2),
          Row(
            children: [
              IconButton(
                onPressed: canGoBack ? () => _step(-1) : null,
                tooltip: 'Previous ${_period.label.toLowerCase()}',
                icon: const Icon(Icons.chevron_left),
                style: IconButton.styleFrom(minimumSize: const Size(44, 44), backgroundColor: colors.card),
              ),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(range.label, textAlign: TextAlign.center, style: nunito(17, FontWeight.w900, colors.ink)),
                ),
              ),
              IconButton(
                onPressed: canGoForward ? () => _step(1) : null,
                tooltip: 'Next ${_period.label.toLowerCase()}',
                icon: const Icon(Icons.chevron_right),
                style: IconButton.styleFrom(minimumSize: const Size(44, 44), backgroundColor: colors.card),
              ),
            ],
          ),
        ],
      ],
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
                  value: metrics.dailyData.isEmpty ? '–' : '${metrics.averageHours.toStringAsFixed(1)}h',
                  // No trend without sleep this period.
                  trend: metrics.dailyData.isEmpty
                      ? TrendDirection.neutral
                      : _calculateTrend(metrics.averageHours, metrics.previousAverageHours),
                  trendPercentage: metrics.dailyData.isEmpty
                      ? 0
                      : _calculateTrendPercentage(metrics.averageHours, metrics.previousAverageHours),
                ),
                loading: () => _buildLoadingCard(),
                error: (_, _) => _buildErrorCard('Sleep'),
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
                error: (_, _) => _buildErrorCard('Mood'),
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
                error: (_, _) => _buildErrorCard('Exercise'),
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
                error: (_, _) => _buildErrorCard('Activities'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSleepChart() {
    final sleepAsync = ref.watch(sleepMetricsProvider(_selectedRange));

    return GardenSection(
      title: 'Sleep',
      colors: GardenColors.of(context),
      child: sleepAsync.when(
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
        error: (_, _) => _buildEmptyState('Error loading sleep data'),
      ),
    );
  }

  Widget _buildSleepLineChart(SleepMetrics metrics) {

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

  Widget _buildActivityBreakdown() {
    final activityAsync = ref.watch(activityMetricsProvider(_selectedRange));
    final colors = GardenColors.of(context);

    return GardenSection(
      title: 'Top activities',
      colors: GardenColors.of(context),
      child: activityAsync.when(
        data: (metrics) {
          if (metrics.topActivities.isEmpty) {
            return _buildEmptyState('No activities logged for this period');
          }

          // Habits on nearly every day say little; list them once, then
          // rank what varied.
          final everyday = [for (final a in metrics.topActivities) if (a.everyday) a.tagName];
          final varied = metrics.topActivities.where((a) => !a.everyday).take(5).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (everyday.isNotEmpty) ...[
                Text('Most days', style: nunito(13, FontWeight.w800, colors.leaf)),
                Text(everyday.join(', '), style: nunito(14, FontWeight.w700, colors.ink)),
                if (varied.isNotEmpty) const SizedBox(height: AppTheme.spacePulse3),
              ],
              if (varied.isNotEmpty) Text('Some days', style: nunito(13, FontWeight.w800, colors.leaf)),
              for (final activity in varied)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacePulse2),
                  child: Row(
                    children: [
                      Expanded(child: Text(activity.tagName, style: nunito(14, FontWeight.w700, colors.ink))),
                      Text('${activity.count} ${activity.count == 1 ? 'day' : 'days'}', style: nunito(14, FontWeight.w900, colors.ink)),
                      const SizedBox(width: AppTheme.spacePulse2),
                      Text('${activity.percentage.toStringAsFixed(0)}%', style: nunito(12, FontWeight.w700, colors.muted)),
                    ],
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _buildEmptyState('Error loading activity data'),
      ),
    );
  }

  Widget _buildInsights() {
    final insightsAsync = ref.watch(metricsInsightsProvider(_selectedRange));
    final colors = GardenColors.of(context);

    return GardenSection(
      title: 'Compared with before',
      colors: GardenColors.of(context),
      child: insightsAsync.when(
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
                      color: colors.leaf,
                    ),
                    const SizedBox(width: AppTheme.spacePulse2),
                    Expanded(
                      child: Text(
                        insight.text,
                        style: nunito(14, FontWeight.w600, colors.ink),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _buildEmptyState('Error generating insights'),
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          style: nunito(14, FontWeight.w600, GardenColors.of(context).muted),
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

/// The kinds of period Metrics shows; all but [all] step with arrows.
enum _Period {
  week('Week'),
  month('Month'),
  year('Year'),
  all('All');

  const _Period(this.label);

  final String label;
}
