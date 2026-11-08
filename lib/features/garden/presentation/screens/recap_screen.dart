import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/garden_providers.dart';
import '../../domain/plant.dart';
import '../garden_style.dart';
import '../widgets/moment_sheet.dart';
import '../widgets/mini_garden.dart';
import 'year_gardens_screen.dart';

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
                _count(r.plants, 'plant'),
                style: nunito(26, FontWeight.w900, colors.ink),
              ),
            ),
            const SizedBox(height: 12),
            _RecapCard(colors: colors, child: MiniGarden(month: r.month, days: r.days)),
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
                  MaterialPageRoute<void>(builder: (_) => YearGardensScreen(year: month.year)),
                ),
                icon: const Icon(Icons.calendar_view_month),
                label: Text('${month.year}’s gardens', style: nunito(14, FontWeight.w800, colors.accent)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.colors, required this.child});

  final GardenColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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

/// The month's days as small pots, in weeks from Monday like the month
/// garden.
