import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/services/database/repositories/journal_repository.dart';
import '../../../../shared/utils/date_utils.dart';
import '../../../garden/presentation/garden_style.dart';
import '../../../garden/presentation/screens/garden_today_screen.dart';
import '../../../garden/presentation/widgets/moment_sheet.dart';
import '../../../journal/data/models/journal_entry.dart';
import '../../../journal/domain/highlights.dart';
import '../../data/models/metric_data.dart';

/// The period's moments, up to today; all time from the first entry.
final periodMomentsProvider = FutureProvider.autoDispose.family<List<JournalEntry>, DateRange>((ref, range) async {
  final db = ref.watch(databaseProvider);
  final first = range.isAllTime ? await db.firstLoggedDay() : null;
  final today = dayOf(DateTime.now());
  final end = range.end.isAfter(today) ? today : dayOf(range.end);
  return JournalRepository(db).inRange(dayOf(first ?? range.start), end);
});

/// How many moments the period has, and a few worth seeing again; each
/// opens its day.
class MomentsSection extends ConsumerWidget {
  const MomentsSection({super.key, required this.range});

  final DateRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);
    final moments = ref.watch(periodMomentsProvider(range)).value;
    if (moments == null || moments.isEmpty) return const SizedBox.shrink();
    final highlights = momentHighlights(moments);
    return GardenSection(
      title: 'Moments',
      subtitle: '${moments.length} ${moments.length == 1 ? 'moment' : 'moments'} written',
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final m in highlights)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => GardenTodayScreen(day: m.date))),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('“${m.text.trim()}”', style: nunito(15, FontWeight.w700, colors.ink)),
                    Text(
                      [DateFormat('EEE d MMM y').format(m.date), if (momentMoodWords[m.mood] case final w?) w].join(' · '),
                      style: nunito(12, FontWeight.w700, colors.muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
