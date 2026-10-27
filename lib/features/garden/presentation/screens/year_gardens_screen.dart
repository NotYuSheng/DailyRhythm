import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../metrics/data/providers/metrics_providers.dart';
import '../../data/garden_providers.dart';
import '../../domain/garden_day.dart';
import '../garden_style.dart';
import '../widgets/mini_garden.dart';
import 'recap_screen.dart';

/// A year of gardens: every month's plants, to look back on. The year's
/// numbers are in Metrics.
class YearGardensScreen extends ConsumerStatefulWidget {
  const YearGardensScreen({super.key, required this.year});

  final int year;

  @override
  ConsumerState<YearGardensScreen> createState() => _YearGardensScreenState();
}

class _YearGardensScreenState extends ConsumerState<YearGardensScreen> {
  late int _year = widget.year;

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    final now = DateTime.now();
    final firstYear = ref.watch(firstLoggedDayProvider).value?.year ?? _year;
    final days = ref.watch(gardenYearProvider(_year));

    Widget arrow(IconData icon, String label, VoidCallback? onPressed) => IconButton(
          onPressed: onPressed,
          tooltip: label,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            backgroundColor: colors.card,
            foregroundColor: colors.ink,
            disabledBackgroundColor: colors.card.withValues(alpha: 0.5),
          ),
        );

    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(backgroundColor: colors.ground, title: const Text('A year of gardens')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: [
          Row(
            children: [
              arrow(Icons.chevron_left, 'Previous year', _year > firstYear ? () => setState(() => _year--) : null),
              Expanded(
                child: Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text('$_year', textAlign: TextAlign.center, style: nunito(28, FontWeight.w900, colors.ink)),
                ),
              ),
              arrow(Icons.chevron_right, 'Next year', _year < now.year ? () => setState(() => _year++) : null),
            ],
          ),
          const SizedBox(height: 12),
          ...days.when(
            loading: () => [const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))],
            error: (e, _) => [Text('Couldn’t load the gardens: $e')],
            data: (list) {
              final plants = list.where((d) => d.plant.logged).length;
              return [
                Text(
                  plants == 0 ? 'Nothing grew in $_year.' : '$plants ${plants == 1 ? 'plant' : 'plants'}',
                  textAlign: TextAlign.center,
                  style: nunito(15, FontWeight.w700, colors.muted),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, box) {
                    // Two months a row on a phone, three on anything wider.
                    final perRow = box.maxWidth >= 600 ? 3 : 2;
                    const gap = 10.0;
                    final width = (box.maxWidth - gap * (perRow - 1)) / perRow;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (var m = 1; m <= 12; m++)
                          if (!(DateTime(_year, m).isAfter(now)))
                            SizedBox(
                              width: width,
                              child: _MonthTile(
                                month: DateTime(_year, m),
                                days: [for (final d in list) if (d.date.month == m) d],
                                colors: colors,
                              ),
                            ),
                      ],
                    );
                  },
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({required this.month, required this.days, required this.colors});

  final DateTime month;
  final List<GardenDay> days;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    final plants = days.where((d) => d.plant.logged).length;
    final name = DateFormat('MMMM').format(month);
    return Material(
      color: colors.bed,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => MonthRecapScreen(month: month))),
        child: Semantics(
          button: true,
          label: '$name: $plants ${plants == 1 ? 'plant' : 'plants'}',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, style: nunito(14, FontWeight.w900, colors.ink))),
                    Text('$plants', style: nunito(13, FontWeight.w800, colors.muted)),
                  ],
                ),
                const SizedBox(height: 6),
                MiniGarden(month: month, days: days),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
