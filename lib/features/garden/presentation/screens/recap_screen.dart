import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/garden_providers.dart';
import '../../domain/plant.dart';
import '../../domain/recap.dart';
import '../garden_style.dart';
import '../widgets/moment_sheet.dart';
import '../widgets/plant_view.dart';

String _hours(double h) {
  final minutes = (h * 60).round();
  return minutes % 60 == 0 ? '${minutes ~/ 60}h' : '${minutes ~/ 60}h ${minutes % 60}m';
}

String _count(int n, String one, [String? many]) => '$n ${n == 1 ? one : many ?? '${one}s'}';

String _plants(List<(PlantSpecies, int)> species) =>
    [for (final (s, n) in species) '$n ${n == 1 ? s.plantName : s.pluralName}'].join(', ');

/// A month in review: its garden, what grew, and a few neutral facts.
class MonthRecapScreen extends ConsumerWidget {
  const MonthRecapScreen({super.key, required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);
    final recap = ref.watch(monthRecapProvider(DateTime(month.year, month.month)));
    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(backgroundColor: colors.ground, title: Text(DateFormat('MMMM y').format(month))),
      body: recap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Couldn’t load the month: $e')),
        data: (r) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Text('Month in review', style: nunito(14, FontWeight.w700, colors.muted)),
            Semantics(
              header: true,
              child: Text(
                '${_count(r.plants, 'plant')}, ${_count(r.flowers, 'flower')}',
                style: nunito(26, FontWeight.w900, colors.ink),
              ),
            ),
            const SizedBox(height: 12),
            _RecapCard(colors: colors, child: _MiniGarden(recap: r)),
            if (r.isEmpty) ...[
              const SizedBox(height: 16),
              Text('Nothing was logged this month. Quiet months are fine too.', style: nunito(15, FontWeight.w600, colors.muted)),
            ] else ...[
              const SizedBox(height: 12),
              _Fact(
                colors: colors,
                title: 'What grew',
                body: '${_plants(r.species)}${r.quietDays > 0 ? '. ${_count(r.quietDays, 'quiet day')}' : ''}',
              ),
              if (r.topActivities.isNotEmpty)
                _Fact(
                  colors: colors,
                  title: 'What the days held',
                  body: [for (final (name, n) in r.topActivities) '$name (${_count(n, 'day')})'].join(', '),
                ),
              if (r.sleepAverage != null)
                _Fact(
                  colors: colors,
                  title: 'Sleep',
                  body: r.sleepShortest == r.sleepLongest
                      ? 'About ${_hours(r.sleepAverage!)} a night'
                      : 'From ${_hours(r.sleepShortest!)} to ${_hours(r.sleepLongest!)}, about ${_hours(r.sleepAverage!)} on average',
                ),
              if (r.moveSessions > 0)
                _Fact(
                  colors: colors,
                  title: 'Movement',
                  body: '${_count(r.moveSessions, 'session')} over ${_count(r.movingDays, 'day')}',
                ),
              if (r.momentCount > 0)
                _RecapCard(
                  colors: colors,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Moments', style: nunito(16, FontWeight.w900, colors.ink)),
                      Text('${_count(r.momentCount, 'moment')} written', style: nunito(14, FontWeight.w600, colors.leaf)),
                      for (final m in r.highlights) ...[
                        const SizedBox(height: 10),
                        Text('“${m.text.trim()}”', style: nunito(15, FontWeight.w700, colors.ink)),
                        Text(
                          [DateFormat('EEE d MMM').format(m.date), if (momentMoodWords[m.mood] case final w?) w].join(' · '),
                          style: nunito(12, FontWeight.w700, colors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: colors.accent),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => YearRecapScreen(year: month.year)),
                ),
                icon: const Icon(Icons.calendar_view_month),
                label: Text('${month.year} in review', style: nunito(14, FontWeight.w800, colors.accent)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A year in review: twelve small gardens and a few facts across them.
class YearRecapScreen extends ConsumerWidget {
  const YearRecapScreen({super.key, required this.year});

  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);
    final recap = ref.watch(yearRecapProvider(year));
    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(backgroundColor: colors.ground, title: Text('$year')),
      body: recap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Couldn’t load the year: $e')),
        data: (r) {
          final month = DateFormat('MMMM');
          final top = r.topSpecies;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              Text('Year in review', style: nunito(14, FontWeight.w700, colors.muted)),
              Semantics(
                header: true,
                child: Text('${_count(r.plants, 'plant')}, ${_count(r.flowers, 'flower')}', style: nunito(26, FontWeight.w900, colors.ink)),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, box) {
                  final columns = box.maxWidth >= 600 ? 4 : 3;
                  const gap = 10.0;
                  final width = (box.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final m in r.months)
                        SizedBox(
                          width: width,
                          child: Semantics(
                            button: true,
                            label: '${month.format(m.month)}: ${_count(m.plants, 'plant')}',
                            excludeSemantics: true,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(builder: (_) => MonthRecapScreen(month: m.month)),
                              ),
                              child: _RecapCard(
                                colors: colors,
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(DateFormat('MMM').format(m.month), style: nunito(13, FontWeight.w900, colors.ink)),
                                    Text('${m.plants}', style: nunito(11, FontWeight.w700, colors.muted)),
                                    const SizedBox(height: 4),
                                    _MiniGarden(recap: m),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              if (r.plants == 0)
                Text('Nothing logged this year yet.', style: nunito(15, FontWeight.w600, colors.muted))
              else ...[
                if (top != null)
                  _Fact(colors: colors, title: 'Grown most', body: '${top.$2} ${top.$2 == 1 ? top.$1.plantName : top.$1.pluralName}'),
                if (r.mostActive case final m?)
                  _Fact(colors: colors, title: 'Most active month', body: '${month.format(m.month)}, ${_count(m.moveSessions, 'movement session')}'),
                if (r.mostMoments case final m?)
                  _Fact(colors: colors, title: 'Most moments', body: '${month.format(m.month)}, ${_count(m.momentCount, 'moment')}'),
                if (r.mostFlowers case final m?)
                  _Fact(colors: colors, title: 'Most in bloom', body: '${month.format(m.month)}, ${_count(m.flowers, 'flower')}'),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.colors, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16)});

  final GardenColors colors;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(20)),
      child: child,
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.colors, required this.title, required this.body});

  final GardenColors colors;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return _RecapCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: nunito(16, FontWeight.w900, colors.ink)),
          const SizedBox(height: 2),
          Text(body, style: nunito(14, FontWeight.w600, colors.leaf)),
        ],
      ),
    );
  }
}

/// The month's days as small pots, seven to a row from the 1st.
class _MiniGarden extends StatelessWidget {
  const _MiniGarden({required this.recap});

  final MonthRecap recap;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) {
          final cell = box.maxWidth / 7;
          return Wrap(
            children: [
              for (final d in recap.days)
                SizedBox(
                  width: cell,
                  child: PlantView(spec: d.plant, width: cell, potColor: potColors[d.date.day % potColors.length]),
                ),
            ],
          );
        },
      ),
    );
  }
}
