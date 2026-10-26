import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/utils/date_utils.dart';
import '../../../tags/data/models/tag.dart';
import '../../../tags/data/providers/tag_providers.dart';
import '../../data/garden_providers.dart';
import '../../domain/garden_day.dart';
import '../../domain/plant.dart';
import '../garden_style.dart';
import '../widgets/plant_view.dart';
import 'garden_today_screen.dart';

/// A month as a garden: one pot per day, a plant in each logged one.
class GardenMonthScreen extends ConsumerStatefulWidget {
  const GardenMonthScreen({super.key, this.month});

  /// Any date in the month to show first; this month when null.
  final DateTime? month;

  @override
  ConsumerState<GardenMonthScreen> createState() => _GardenMonthScreenState();
}

class _GardenMonthScreenState extends ConsumerState<GardenMonthScreen> {
  late final DateTime _start = dayOf(widget.month ?? DateTime.now());
  late DateTime _month = DateTime(_start.year, _start.month);
  late DateTime _picked = _start;

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      final today = dayOf(DateTime.now());
      final last = DateTime(_month.year, _month.month + 1, 0);
      _picked = last.isBefore(today) ? last : (today.month == _month.month && today.year == _month.year ? today : _month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    final days = ref.watch(gardenMonthProvider(_month));
    final today = dayOf(DateTime.now());
    final isCurrentMonth = _month.year == today.year && _month.month == today.month;

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: days.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Couldn’t load the garden: $e')),
          data: (list) {
            final past = [for (final d in list) if (!d.date.isAfter(today)) d];
            final plants = past.where((d) => d.plant.logged).length;
            final flowers = past.where((d) => d.plant.logged && d.plant.flower).length;
            final picked = list.firstWhere((d) => d.date == _picked, orElse: () => list.first);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
              children: [
                Row(
                  children: [
                    // Shown when opened from Today; as a tab there is nowhere to go back to.
                    if (Navigator.canPop(context)) ...[
                      _RoundIcon(
                        icon: Icons.chevron_left,
                        label: 'Back to today',
                        colors: colors,
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${DateFormat('MMMM y').format(_month)} garden', style: nunito(14, FontWeight.w700, colors.muted)),
                          Semantics(
                            header: true,
                            child: Text(
                              '$plants ${plants == 1 ? 'plant' : 'plants'}, $flowers ${flowers == 1 ? 'flower' : 'flowers'}',
                              style: nunito(26, FontWeight.w900, colors.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoundIcon(icon: Icons.arrow_back, label: 'Previous month', colors: colors, onPressed: () => _moveMonth(-1)),
                    Text(DateFormat('MMMM').format(_month), style: nunito(16, FontWeight.w900, colors.ink)),
                    _RoundIcon(
                      icon: Icons.arrow_forward,
                      label: 'Next month',
                      colors: colors,
                      onPressed: isCurrentMonth ? null : () => _moveMonth(1),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _MonthGrid(
                  days: list,
                  today: today,
                  picked: _picked,
                  colors: colors,
                  onPick: (d) => setState(() => _picked = d),
                ),
                const SizedBox(height: 14),
                _DayCard(day: picked, colors: colors),
                const SizedBox(height: 14),
                Text(
                  'Empty pots are just quiet days. Nothing here ever wilts.',
                  textAlign: TextAlign.center,
                  style: nunito(14, FontWeight.w700, colors.muted),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.days, required this.today, required this.picked, required this.colors, required this.onPick});

  final List<GardenDay> days;
  final DateTime today;
  final DateTime picked;
  final GardenColors colors;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    // Weeks start on Monday; blank cells before the 1st.
    final lead = days.first.date.weekday - 1;
    final weekdays = DateFormat.E();
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(30)),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      weekdays.format(DateTime(2024, 1, 1 + i)).substring(0, 1),
                      textAlign: TextAlign.center,
                      style: nunito(11, FontWeight.w800, colors.muted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.72,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox.shrink(),
              for (final d in days) _DayCell(day: d, future: d.date.isAfter(today), selected: d.date == picked, colors: colors, onPick: onPick),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.future, required this.selected, required this.colors, required this.onPick});

  final GardenDay day;
  final bool future;
  final bool selected;
  final GardenColors colors;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final label = '${DateFormat('d MMMM').format(day.date)}, '
        '${future ? 'not yet' : day.plant.logged ? day.title : 'nothing logged'}';
    return Semantics(
      button: !future,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: future ? 0.45 : 1,
        child: InkWell(
          onTap: future ? null : () => onPick(day.date),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: selected ? colors.ground : Colors.transparent,
              border: Border.all(color: selected ? colors.accent : Colors.transparent, width: 2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: LayoutBuilder(
              builder: (context, box) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PlantView(
                    spec: future ? PlantSpec(species: day.plant.species, logged: false) : day.plant,
                    width: (box.maxWidth - 6).clamp(20, 48),
                    potColor: future ? '#E4EDE7' : potColors[day.date.day % potColors.length],
                  ),
                  Text('${day.date.day}', style: nunito(11, FontWeight.w800, colors.muted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayCard extends ConsumerWidget {
  const _DayCard({required this.day, required this.colors});

  final GardenDay day;
  final GardenColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moments = ref.watch(momentsProvider(day.date)).value ?? const [];
    final tags = {for (final t in ref.watch(allTagsProvider).value ?? const <Tag>[]) t.id: t.name};
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: colors.bed, borderRadius: BorderRadius.circular(26)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(DateFormat('EEEE d MMMM').format(day.date), style: nunito(14, FontWeight.w800, colors.leaf)),
            Text(day.title, style: nunito(18, FontWeight.w900, colors.ink)),
            Text(day.detail, style: nunito(14, FontWeight.w600, colors.leaf)),
            if (moments.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final m in moments) MomentTile(moment: m, tagNames: tags, colors: colors),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: colors.accent),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => GardenTodayScreen(day: day.date)),
                ),
                child: Text('Open this day', style: nunito(14, FontWeight.w800, colors.accent)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.label, required this.colors, required this.onPressed});

  final IconData icon;
  final String label;
  final GardenColors colors;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
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
  }
}
