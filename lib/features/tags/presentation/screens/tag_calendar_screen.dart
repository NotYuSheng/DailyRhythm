import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/utils/date_utils.dart';
import '../../../garden/presentation/garden_style.dart';
import '../../../garden/presentation/screens/garden_today_screen.dart';
import '../../data/models/tag.dart';
import '../../data/providers/tag_providers.dart';
import '../tag_icons.dart';

/// The days a tag was logged on.
final tagDaysProvider = FutureProvider.autoDispose.family<Set<DateTime>, int>((ref, tagId) async {
  final db = await ref.watch(databaseProvider).database;
  final rows = await db.query('activity_entries', columns: ['date'], where: 'tagId = ?', whereArgs: [tagId]);
  return {for (final r in rows) dayOf(DateTime.parse(r['date'] as String))};
});

/// Opens the tag calendar for [tag].
Future<void> openTagCalendar(BuildContext context, Tag tag) =>
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => TagCalendarScreen(tag: tag)));

/// Lets the user pick a tag, their most used first, and opens its calendar.
Future<void> pickTagCalendar(BuildContext context, WidgetRef ref) async {
  final colors = GardenColors.of(context);
  final List<Tag> tags = ref.read(allTagsProvider).value ?? await ref.read(allTagsProvider.future);
  final Map<int, int> uses = ref.read(tagUseCountsProvider).value ?? await ref.read(tagUseCountsProvider.future);
  if (!context.mounted) return;
  final sorted = [for (final t in tags) if ((uses[t.id] ?? 0) > 0) t]..sort((a, b) => (uses[b.id] ?? 0).compareTo(uses[a.id] ?? 0));
  final picked = await showModalBottomSheet<Tag>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Text('See a tag on the calendar', style: nunito(20, FontWeight.w900, colors.ink)),
          const SizedBox(height: 4),
          Text('Most used first', style: nunito(13, FontWeight.w600, colors.muted)),
          const SizedBox(height: 12),
          if (sorted.isEmpty) Text('Tag a day first.', style: nunito(14, FontWeight.w600, colors.muted)),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in sorted)
                ActionChip(
                  avatar: Icon(tagIcon(t), size: 18),
                  label: Text('${t.name}  ${uses[t.id]}'),
                  onPressed: () => Navigator.pop(context, t),
                ),
            ],
          ),
        ],
      ),
    ),
  );
  if (picked != null && context.mounted) await openTagCalendar(context, picked);
}

/// Every day a tag was logged, month by month, with how often and when.
/// Tapping a day opens it.
class TagCalendarScreen extends ConsumerStatefulWidget {
  const TagCalendarScreen({super.key, required this.tag});

  final Tag tag;

  @override
  ConsumerState<TagCalendarScreen> createState() => _TagCalendarScreenState();
}

class _TagCalendarScreenState extends ConsumerState<TagCalendarScreen> {
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    final tone = DayTone.tag;
    final today = dayOf(DateTime.now());
    final days = ref.watch(tagDaysProvider(widget.tag.id!));

    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(
        backgroundColor: colors.ground,
        title: Row(
          children: [
            Icon(tagIcon(widget.tag), size: 22, color: tone.ink(context)),
            const SizedBox(width: 8),
            Flexible(child: Text(widget.tag.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: days.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Couldn’t load the days: $e')),
        data: (set) {
          final sorted = set.toList()..sort();
          // Opens on the month it was last used.
          final month = _month ?? (sorted.isEmpty ? DateTime(today.year, today.month) : DateTime(sorted.last.year, sorted.last.month));
          final first = sorted.isEmpty ? month : DateTime(sorted.first.year, sorted.first.month);
          final inMonth = sorted.where((d) => d.year == month.year && d.month == month.month).length;
          final weekdays = List.filled(7, 0);
          for (final d in sorted) {
            weekdays[d.weekday - 1]++;
          }
          final top = weekdays.indexOf(weekdays.reduce((a, b) => a > b ? a : b));
          final topShare = sorted.isEmpty ? 0.0 : weekdays[top] / sorted.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              Row(
                children: [
                  _Stat(value: NumberFormat.decimalPattern().format(sorted.length), label: sorted.length == 1 ? 'day in all' : 'days in all', colors: colors),
                  _Stat(
                    value: sorted.isEmpty ? '–' : _ago(sorted.last, today),
                    label: 'last time',
                    colors: colors,
                  ),
                  // A weekday only when it clearly leads (a quarter or more).
                  _Stat(
                    value: sorted.length >= 5 && topShare >= 0.25 ? DateFormat('EEE').format(DateTime(2024, 1, top + 1)) : '–',
                    label: 'most often',
                    colors: colors,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: month.isAfter(first) ? () => setState(() => _month = DateTime(month.year, month.month - 1)) : null,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(DateFormat('MMMM y').format(month), style: nunito(16, FontWeight.w900, colors.ink)),
                        ),
                        Text('$inMonth ${inMonth == 1 ? 'day' : 'days'}', style: nunito(13, FontWeight.w700, colors.muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: month.year == today.year && month.month == today.month
                        ? null
                        : () => setState(() => _month = DateTime(month.year, month.month + 1)),
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _Month(month: month, marked: set, today: today, colors: colors, tone: tone),
              const SizedBox(height: 12),
              Text('Tap a day to open it.', textAlign: TextAlign.center, style: nunito(13, FontWeight.w600, colors.muted)),
            ],
          );
        },
      ),
    );
  }

  static String _ago(DateTime day, DateTime today) {
    final days = daysBetween(day, today);
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    return day.year == today.year ? DateFormat('d MMM').format(day) : DateFormat('MMM y').format(day);
  }
}

class _Month extends StatelessWidget {
  const _Month({required this.month, required this.marked, required this.today, required this.colors, required this.tone});

  final DateTime month;
  final Set<DateTime> marked;
  final DateTime today;
  final GardenColors colors;
  final DayTone tone;

  @override
  Widget build(BuildContext context) {
    final length = DateTime(month.year, month.month + 1, 0).day;
    final lead = month.weekday - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(26)),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      DateFormat.E().format(DateTime(2024, 1, 1 + i)).substring(0, 1),
                      textAlign: TextAlign.center,
                      style: nunito(11, FontWeight.w800, colors.muted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox.shrink(),
              for (var d = 1; d <= length; d++) _cell(context, DateTime(month.year, month.month, d)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, DateTime day) {
    final on = marked.contains(day);
    final future = day.isAfter(today);
    final label = '${DateFormat('EEEE d MMMM').format(day)}${on ? ', tagged' : ''}';
    return Semantics(
      button: !future,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: on ? tone.tint(context) : Colors.transparent,
        shape: CircleBorder(side: day == today ? BorderSide(color: colors.accent, width: 1.5) : BorderSide.none),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: future ? null : () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => GardenTodayScreen(day: day))),
          child: Center(
            child: Text(
              '${day.day}',
              style: nunito(13, on ? FontWeight.w900 : FontWeight.w600, on ? tone.ink(context) : (future ? colors.hill : colors.muted)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.colors});

  final String value;
  final String label;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: nunito(18, FontWeight.w900, colors.ink))),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: nunito(12, FontWeight.w700, colors.muted)),
          ],
        ),
      ),
    );
  }
}
