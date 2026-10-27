import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/metric_data.dart';
import '../../data/providers/metrics_providers.dart';
import '../../../garden/presentation/garden_style.dart';
import '../widgets/day_ratings_section.dart';
import '../widgets/fun_facts_section.dart';
import '../../data/models/period_overview.dart';
import '../widgets/period_overview_section.dart';
import '../widgets/weight_section.dart';

class MetricsScreen extends ConsumerStatefulWidget {
  const MetricsScreen({super.key});

  @override
  ConsumerState<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends ConsumerState<MetricsScreen> {
  _Period _period = _Period.month;

  /// Any day in the period shown; arrows move it back and forward. Null
  /// follows today, so a screen left open shows the new month when it comes.
  DateTime? _anchor;

  DateRange get _selectedRange => _selectedRangeFor(_anchor ?? DateTime.now());

  void _step(int delta) => setState(() {
        final day = _anchor ?? DateTime.now();
        final next = switch (_period) {
          _Period.week => DateTime(day.year, day.month, day.day + 7 * delta),
          _Period.month => DateTime(day.year, day.month + delta),
          _Period.year => DateTime(day.year + delta),
          _Period.all => day,
        };
        // Back at the period holding today: follow it again.
        final today = DateTime.now();
        _anchor = _selectedRangeFor(next).end.isBefore(DateTime(today.year, today.month, today.day)) ? next : null;
      });

  DateRange _selectedRangeFor(DateTime day) => switch (_period) {
        _Period.week => DateRange.week(day),
        _Period.month => DateRange.month(day),
        _Period.year => DateRange.year(day),
        _Period.all => DateRange.allTime(),
      };

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

            // The period in a few lines: sleep, mood and exercise against
            // the period before.
            _buildInsights(),
            const SizedBox(height: AppTheme.spacePulse3),

            // Every day, mood and sleep by group, tags that stood out, and
            // a row per group: a week by day up to all time by year.
            PeriodOverviewSection(scale: _period.scale, range: _selectedRange),
            const SizedBox(height: AppTheme.spacePulse3),

            // Weight over the period, and logging today's.
            WeightSection(range: _selectedRange),
            const SizedBox(height: AppTheme.spacePulse3),

            // Mood, energy, stress and focus; tag comparisons; watch
            DayRatingsSection(range: _selectedRange),
            const SizedBox(height: AppTheme.spacePulse3),

            // Activity Breakdown
            _buildActivityBreakdown(),
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
              _anchor = null;
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
      // All time has nothing before it.
      title: _selectedRange.isAllTime ? 'At a glance' : 'Compared with before',
      colors: GardenColors.of(context),
      child: insightsAsync.when(
        data: (insights) {
          if (insights.isEmpty) {
            return _buildEmptyState('Not enough logged yet to compare');
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
}

/// The kinds of period Metrics shows; all but [all] step with arrows.
enum _Period {
  week('Week', OverviewScale.week),
  month('Month', OverviewScale.month),
  year('Year', OverviewScale.year),
  all('All', OverviewScale.all);

  const _Period(this.label, this.scale);

  final String label;
  final OverviewScale scale;
}
