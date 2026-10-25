import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/models/day_checkin.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/services/database/repositories/checkin_repository.dart';
import '../../../../shared/utils/date_utils.dart';
import '../../../journal/data/models/journal_entry.dart';
import '../../../tags/data/models/tag.dart';
import '../../../tags/data/providers/tag_providers.dart';
import '../../data/garden_providers.dart';
import '../../domain/garden_day.dart';
import '../../domain/plant.dart';
import '../garden_style.dart';
import '../widgets/moment_sheet.dart';
import '../widgets/plant_view.dart';
import 'garden_month_screen.dart';

/// Today's plant, what today was mostly about, a quick check-in and the
/// day's moments.
class GardenTodayScreen extends ConsumerWidget {
  const GardenTodayScreen({super.key, this.day});

  /// The day shown; today when null.
  final DateTime? day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);
    final today = dayOf(day ?? DateTime.now());
    final isToday = today == dayOf(DateTime.now());
    final garden = ref.watch(gardenDayProvider(today));
    final checkin = ref.watch(checkinProvider(today)).value;
    final moments = ref.watch(momentsProvider(today)).value ?? const <JournalEntry>[];
    final tags = {for (final t in ref.watch(allTagsProvider).value ?? const <Tag>[]) t.id: t.name};

    Future<void> saveCheckin({int? energy, int? stress, int? focus, String? plant, bool clearPlant = false}) async {
      await CheckinRepository(ref.read(databaseProvider))
          .update(today, energy: energy, stress: stress, focus: focus, plantOverride: plant, clearPlant: clearPlant);
      invalidateGardenDay(ref, today);
    }

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: garden.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Couldn’t load today: $e')),
          data: (g) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (Navigator.canPop(context)) ...[
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back',
                      icon: const Icon(Icons.chevron_left),
                      style: IconButton.styleFrom(minimumSize: const Size(44, 44), backgroundColor: colors.card, foregroundColor: colors.ink),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('EEEE d MMMM').format(today), style: nunito(15, FontWeight.w700, colors.muted)),
                        Semantics(header: true, child: Text(isToday ? 'Today’s plant' : 'This day’s plant', style: nunito(30, FontWeight.w900, colors.ink))),
                      ],
                    ),
                  ),
                  _PillButton(
                    label: 'Garden',
                    colors: colors,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => GardenMonthScreen(month: today)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PlantBed(day: g, caption: _caption(g, isToday), colors: colors),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: isToday ? 'Today was mostly… ' : 'This day was mostly… '),
                  TextSpan(
                    text: g.chosen ? '(your pick)' : '(picks the plant)',
                    style: nunito(16, FontWeight.w700, colors.muted),
                  ),
                ]),
                style: nunito(16, FontWeight.w900, colors.ink),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in PlantSpecies.values)
                    _Chip(
                      label: s.label,
                      selected: g.plant.species == s,
                      colors: colors,
                      // Picking the chosen plant again goes back to automatic.
                      onPressed: () => g.chosen && g.plant.species == s
                          ? saveCheckin(clearPlant: true)
                          : saveCheckin(plant: s.name),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _Stats(day: g, momentCount: moments.length, colors: colors),
              const SizedBox(height: 16),
              _CheckinCard(
                checkin: checkin,
                colors: colors,
                onEnergy: (v) => saveCheckin(energy: v),
                onStress: (v) => saveCheckin(stress: v),
                onFocus: (v) => saveCheckin(focus: v),
              ),
              const SizedBox(height: 16),
              _Moments(moments: moments, tagNames: tags, colors: colors),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  if (await showMomentSheet(context, today)) invalidateGardenDay(ref, today);
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: const StadiumBorder(),
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onAccent,
                ),
                child: Text('Log a moment', style: nunito(15, FontWeight.w900, colors.onAccent)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _caption(GardenDay g, bool isToday) {
    final name = g.plant.species.plantName;
    final when = isToday ? 'today' : 'that day';
    if (!g.plant.logged) return isToday ? 'An empty pot, ready for whatever today brings.' : 'An empty pot: a quiet day.';
    if (g.plant.flower) return 'Your $name is in bloom. A good moment $when.';
    if (g.plant.move >= 3) return 'A leafy $name! Lots of moving $when.';
    return 'A $name, grown from ${isToday ? 'last night’s' : 'the night’s'} sleep.';
  }
}

class _PlantBed extends StatelessWidget {
  const _PlantBed({required this.day, required this.caption, required this.colors});

  final GardenDay day;
  final String caption;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: colors.bed, borderRadius: BorderRadius.circular(34)),
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(caption, textAlign: TextAlign.center, style: nunito(15, FontWeight.w800, colors.leaf)),
          ),
          PlantView(spec: day.plant, width: 210, sway: true, potColor: potColors[day.date.day % potColors.length]),
          // The hill the pot stands on.
          Container(
            height: 26,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.hill,
              borderRadius: const BorderRadius.vertical(top: Radius.elliptical(220, 26)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.day, required this.momentCount, required this.colors});

  final GardenDay day;
  final int momentCount;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    final hours = day.sleepHours;
    final sleep = hours == null ? '—' : '${hours.floor()}h ${((hours - hours.floor()) * 60).round()}m';
    final moves = day.moveCount;
    return Row(
      children: [
        _Stat(label: 'SLEEP', value: sleep, labelColor: const Color(0xFF2D6CA8), colors: colors),
        const SizedBox(width: 8),
        _Stat(label: 'MOVING', value: '$moves', labelColor: const Color(0xFF8A5F00), colors: colors),
        const SizedBox(width: 8),
        _Stat(label: 'MOMENTS', value: '$momentCount', labelColor: const Color(0xFFB0305C), colors: colors),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.labelColor, required this.colors});

  final String label;
  final String value;
  final Color labelColor;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Text(label, style: nunito(12, FontWeight.w800, dark ? colors.muted : labelColor)),
            FittedBox(child: Text(value, style: nunito(20, FontWeight.w900, colors.ink))),
          ],
        ),
      ),
    );
  }
}

/// Energy, stress and focus relative to a usual day, from −2 to +2.
class _CheckinCard extends StatelessWidget {
  const _CheckinCard({
    required this.checkin,
    required this.colors,
    required this.onEnergy,
    required this.onStress,
    required this.onFocus,
  });

  final DayCheckin? checkin;
  final GardenColors colors;
  final ValueChanged<int> onEnergy;
  final ValueChanged<int> onStress;
  final ValueChanged<int> onFocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Compared with a usual day', style: nunito(16, FontWeight.w900, colors.ink)),
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: Row(
              children: [
                const SizedBox(width: _RatingRow.labelWidth),
                for (final (word, align) in const [('lower', TextAlign.left), ('usual', TextAlign.center), ('higher', TextAlign.right)])
                  Expanded(child: Text(word, textAlign: align, style: nunito(12, FontWeight.w700, colors.muted))),
              ],
            ),
          ),
          _RatingRow(label: 'Energy', value: checkin?.energy, onChanged: onEnergy, colors: colors),
          _RatingRow(label: 'Stress', value: checkin?.stress, onChanged: onStress, colors: colors),
          _RatingRow(label: 'Focus', value: checkin?.focus, onChanged: onFocus, colors: colors),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.label, required this.value, required this.onChanged, required this.colors});

  final String label;
  final int? value;
  final ValueChanged<int> onChanged;
  final GardenColors colors;

  static const labelWidth = 64.0;

  static const _words = {-2: 'much lower', -1: 'a bit lower', 0: 'usual', 1: 'a bit higher', 2: 'much higher'};

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: labelWidth, child: Text(label, style: nunito(14, FontWeight.w800, colors.leaf))),
        Expanded(
          child: Row(
            children: [
              for (final MapEntry(key: v, value: word) in _words.entries)
                Expanded(child: Semantics(
                  button: true,
                  selected: value == v,
                  label: '$label $word',
                  child: InkResponse(
                    onTap: () => onChanged(v),
                    radius: 22,
                    child: SizedBox(
                      height: 44,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: v == 0 ? 22 : 16 + v.abs() * 3,
                          height: v == 0 ? 22 : 16 + v.abs() * 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: value == v ? colors.accent : Colors.transparent,
                            border: Border.all(color: value == v ? colors.accent : colors.muted, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                )),
            ],
          ),
        ),
      ],
    );
  }
}

class _Moments extends StatelessWidget {
  const _Moments({required this.moments, required this.tagNames, required this.colors});

  final List<JournalEntry> moments;
  final Map<int?, String> tagNames;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    if (moments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Moments', style: nunito(16, FontWeight.w900, colors.ink)),
        const SizedBox(height: 8),
        for (final m in moments) MomentTile(moment: m, tagNames: tagNames, colors: colors),
      ],
    );
  }
}

/// One moment: time, mood word, text and what it was about.
class MomentTile extends StatelessWidget {
  const MomentTile({super.key, required this.moment, required this.tagNames, required this.colors});

  final JournalEntry moment;
  final Map<int?, String> tagNames;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (moment.time != null) DateFormat('HH:mm').format(moment.time!),
      if (moment.mood != null) momentMoodWords[moment.mood],
    ].join(' · ');
    final about = [for (final id in moment.tagIds) tagNames[id]].whereType<String>().join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meta.isNotEmpty) Text(meta, style: nunito(12, FontWeight.w800, colors.muted)),
          if (moment.text.isNotEmpty) Text(moment.text, style: nunito(15, FontWeight.w600, colors.ink)),
          if (about.isNotEmpty) Text(about, style: nunito(13, FontWeight.w700, colors.leaf)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.colors, required this.onPressed});

  final String label;
  final bool selected;
  final GardenColors colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: const StadiumBorder(),
          backgroundColor: selected ? colors.accent : colors.card,
          foregroundColor: selected ? colors.onAccent : colors.leaf,
        ),
        child: Text(label, style: nunito(13, FontWeight.w800, selected ? colors.onAccent : colors.leaf)),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.colors, required this.onPressed});

  final String label;
  final GardenColors colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: const StadiumBorder(),
        backgroundColor: colors.card,
        foregroundColor: colors.accent,
      ),
      child: Text(label, style: nunito(14, FontWeight.w800, colors.accent)),
    );
  }
}
