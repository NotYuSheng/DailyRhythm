import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/database/database_provider.dart';
import '../../garden/presentation/garden_style.dart';
import '../data/tidy_service.dart';
import 'tidy_screen.dart';

/// Whether Today offers a tidy-up of last month in a month's first week.
class TidyMonthlyNotifier extends Notifier<bool> {
  static const key = 'tidy_monthly';

  @override
  bool build() {
    SharedPreferences.getInstance().then((p) {
      if (p.getBool(key) case final on?) state = on;
    });
    return true;
  }

  Future<void> set(bool on) async {
    state = on;
    await (await SharedPreferences.getInstance()).setBool(key, on);
  }
}

final tidyMonthlyProvider = NotifierProvider<TidyMonthlyNotifier, bool>(TidyMonthlyNotifier.new);

/// Last month and how much there is to look at in it, while it's worth
/// offering: the first week of a month, not yet done or put off.
final tidyPromptProvider = FutureProvider.autoDispose<(DateTime, int)?>((ref) async {
  if (!ref.watch(tidyMonthlyProvider)) return null;
  final today = DateTime.now();
  if (today.day > 7) return null;
  final month = DateTime(today.year, today.month - 1);
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString(TidyPrompt.doneKey) == DateFormat('yyyy-MM').format(month)) return null;
  final report = await TidyService(ref.watch(databaseProvider)).check(month, DateTime(today.year, today.month, 0));
  final count = report.fixes.length + report.flags.length;
  return count == 0 ? null : (month, count);
});

/// "Tidy up October: 12 things to look at", on Today.
class TidyPrompt extends ConsumerWidget {
  const TidyPrompt({super.key});

  static const doneKey = 'tidy_prompt_done';

  Future<void> _done(WidgetRef ref, DateTime month) async {
    await (await SharedPreferences.getInstance()).setString(doneKey, DateFormat('yyyy-MM').format(month));
    ref.invalidate(tidyPromptProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prompt = ref.watch(tidyPromptProvider).value;
    if (prompt == null) return const SizedBox.shrink();
    final (month, count) = prompt;
    final colors = GardenColors.of(context);
    final name = DateFormat.MMMM().format(month);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(26)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tidy up $name', style: nunito(17, FontWeight.w900, colors.ink)),
            Text('$count ${count == 1 ? 'thing' : 'things'} to look at, a few minutes.', style: nunito(13, FontWeight.w600, colors.muted)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => _done(ref, month), child: const Text('Not now')),
                FilledButton.tonal(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => TidyScreen(start: month, end: DateTime(month.year, month.month + 1, 0), title: 'Tidy up $name')),
                    );
                    await _done(ref, month);
                  },
                  child: const Text('Look'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
