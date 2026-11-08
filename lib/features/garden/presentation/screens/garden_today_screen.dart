import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/models/day_checkin.dart';
import '../../../../shared/models/mood_entry.dart';
import '../../../../shared/providers/common_providers.dart';
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
import '../widgets/day_log_card.dart';
import '../widgets/garden_chip.dart';
import '../widgets/moment_sheet.dart';
import '../widgets/plant_view.dart';
import 'garden_month_screen.dart';

/// One day: its plant, what it was mostly about, how it went, its stats and
/// moments. Opens on today; the arrows step to other days.
class GardenTodayScreen extends ConsumerStatefulWidget {
  const GardenTodayScreen({super.key, this.day});

  /// The day shown first; today when null.
  final DateTime? day;

  @override
  ConsumerState<GardenTodayScreen> createState() => _GardenTodayScreenState();
}

class _GardenTodayScreenState extends ConsumerState<GardenTodayScreen> {
  late DateTime _day = dayOf(widget.day ?? DateTime.now());

  void _go(int days) => setState(() => _day = DateTime(_day.year, _day.month, _day.day + days));

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    final today = _day;
    final now = dayOf(DateTime.now());
    final isToday = today == now;
    final mood = ref.watch(moodEntryProvider(today)).value;
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
                    _RoundButton(icon: Icons.close, tooltip: 'Close', colors: colors, onPressed: () => Navigator.pop(context)),
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
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _RoundButton(icon: Icons.chevron_left, tooltip: 'Previous day', colors: colors, onPressed: () => _go(-1)),
                  const SizedBox(width: 8),
                  _RoundButton(
                    icon: Icons.chevron_right,
                    tooltip: 'Next day',
                    colors: colors,
                    onPressed: isToday ? null : () => _go(1),
                  ),
                  const Spacer(),
                  if (!isToday) ...[
                    _PillButton(label: 'Today', colors: colors, onPressed: () => setState(() => _day = now)),
                    const SizedBox(width: 8),
                  ],
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
                    GardenChip(
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
              _CheckinCard(
                checkin: checkin,
                mood: mood?.moodLevel,
                isToday: isToday,
                colors: colors,
                onMood: (level) async {
                  // Change only the level: the day's mood notes stay.
                  await ref.read(databaseProvider).upsertMoodEntry(
                        MoodEntry(
                          date: today,
                          timestamp: DateTime.now(),
                          moodLevel: level,
                          emoji: mood?.emoji ?? '',
                          notes: mood?.notes,
                        ),
                      );
                  invalidateDayLog(ref, today);
                },
                onEnergy: (v) => saveCheckin(energy: v),
                onStress: (v) => saveCheckin(stress: v),
                onFocus: (v) => saveCheckin(focus: v),
              ),
              const SizedBox(height: 16),
              DayLogCard(day: today),
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
    if (!g.plant.logged) return isToday ? 'An empty pot, ready for whatever today brings.' : 'An empty pot: a quiet day.';
    return 'A ${g.plant.species.plantName} for ${g.plant.species.dayWord}. ${g.reason}';
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

class _CheckinCard extends StatelessWidget {
  const _CheckinCard({
    required this.checkin,
    required this.mood,
    required this.isToday,
    required this.onMood,
    required this.colors,
    required this.onEnergy,
    required this.onStress,
    required this.onFocus,
  });

  final DayCheckin? checkin;
  final int? mood;
  final bool isToday;
  final ValueChanged<int> onMood;
  final GardenColors colors;
  final ValueChanged<int> onEnergy;
  final ValueChanged<int> onStress;
  final ValueChanged<int> onFocus;

  /// Words under the left end, middle and right end of the dots.
  Widget _scale(List<String> words) => ExcludeSemantics(
        child: Row(
          children: [
            const SizedBox(width: _RatingRow.labelWidth),
            for (final (word, align) in [(words[0], TextAlign.left), (words[1], TextAlign.center), (words[2], TextAlign.right)])
              Expanded(child: Text(word, textAlign: align, style: nunito(12, FontWeight.w700, colors.muted))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isToday ? 'How today went' : 'How the day went', style: nunito(16, FontWeight.w900, colors.ink)),
          const SizedBox(height: 6),
          _scale(const ['awful', 'meh', 'great']),
          _RatingRow(label: 'Mood', value: mood, onChanged: onMood, colors: colors, words: _RatingRow.mood),
          const SizedBox(height: 10),
          Text('Compared with a usual day', style: nunito(14, FontWeight.w800, colors.leaf)),
          const SizedBox(height: 4),
          _scale(const ['lower', 'usual', 'higher']),
          _RatingRow(label: 'Energy', value: checkin?.energy, onChanged: onEnergy, colors: colors),
          _RatingRow(label: 'Stress', value: checkin?.stress, onChanged: onStress, colors: colors),
          _RatingRow(label: 'Focus', value: checkin?.focus, onChanged: onFocus, colors: colors),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.colors,
    this.words = relative,
  });

  final String label;
  final int? value;
  final ValueChanged<int> onChanged;
  final GardenColors colors;

  /// The five choices, low to high, with the words read out for each.
  final Map<int, String> words;

  static const labelWidth = 64.0;

  static const relative = {-2: 'much lower', -1: 'a bit lower', 0: 'usual', 1: 'a bit higher', 2: 'much higher'};
  static const mood = {1: 'awful', 2: 'bad', 3: 'meh', 4: 'good', 5: 'great'};

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: labelWidth, child: Text(label, style: nunito(14, FontWeight.w800, colors.leaf))),
        Expanded(
          child: Row(
            children: [
              for (final (i, MapEntry(key: v, value: word)) in words.entries.indexed)
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
                          // The middle dot and the ends are larger.
                          width: i == 2 ? 22 : 16 + (i - 2).abs() * 3,
                          height: i == 2 ? 22 : 16 + (i - 2).abs() * 3,
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

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.colors, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final GardenColors colors;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        backgroundColor: colors.card,
        foregroundColor: colors.ink,
        disabledBackgroundColor: colors.card.withValues(alpha: 0.5),
        disabledForegroundColor: colors.muted.withValues(alpha: 0.5),
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
