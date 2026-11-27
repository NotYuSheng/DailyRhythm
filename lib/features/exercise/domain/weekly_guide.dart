import '../data/models/exercise_entry.dart';
import 'effort.dart';

/// What a week's exercise is checked against. The defaults are the WHO's
/// 2020 guidelines for adults, which the ACSM shares: 150–300 minutes of
/// moderate activity a week (a vigorous minute counts as two) and muscle
/// strengthening on 2 or more days.
class WeeklyTargets {
  const WeeklyTargets({this.minutes = 150, this.strengthDays = 2});

  final int minutes;
  final int strengthDays;

  static const minuteChoices = [75, 150, 300];
  static const strengthChoices = [1, 2, 3];
}

/// The last 7 days against [WeeklyTargets], with a few lines of advice.
class WeeklyGuide {
  const WeeklyGuide({required this.minutes, required this.strengthDays, required this.targets, required this.advice});

  /// Active minutes, moderate-equivalent: vigorous ones count double.
  final double minutes;
  final int strengthDays;
  final WeeklyTargets targets;
  final List<String> advice;

  /// A logged exercise's minutes, moderate-equivalent. A run or a hard
  /// sport is vigorous; a set of weights is about two minutes with rest;
  /// one that felt easy counts half, one that felt hard (7+) double.
  static double minutesOf(ExerciseEntry e) {
    final timed = e.duration == null || e.duration!.inSeconds <= 0 ? null : e.duration!.inSeconds / 60;
    final (minutes, vigorous) = switch (e.type) {
      ExerciseType.run => (timed ?? (e.distance ?? 3) * 6, true),
      ExerciseType.sport => (timed ?? 60, Effort.sportMets(e.exerciseName) >= 6),
      ExerciseType.weightLifting => (2.0 * (e.sets ?? 1), false),
    };
    final rpe = e.rpe;
    if (rpe != null && rpe <= 3) return minutes * 0.5;
    return minutes * (vigorous || (rpe ?? 0) >= 7 ? 2 : 1);
  }

  /// [week] is the last 7 days' entries, [recent] the last 4 weeks' (for
  /// repeats); [watchMinutes] a watch's intensity minutes by day, which a
  /// day takes when higher (they're usually the same workout).
  static WeeklyGuide from({
    required List<ExerciseEntry> week,
    required List<ExerciseEntry> recent,
    Map<DateTime, double> watchMinutes = const {},
    WeeklyTargets targets = const WeeklyTargets(),
  }) {
    DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
    final byDay = <DateTime, double>{};
    for (final e in week) {
      byDay[day(e.date)] = (byDay[day(e.date)] ?? 0) + minutesOf(e);
    }
    for (final MapEntry(key: d, value: m) in watchMinutes.entries) {
      if (m > (byDay[day(d)] ?? 0)) byDay[day(d)] = m;
    }
    final minutes = byDay.values.fold(0.0, (a, b) => a + b);
    final strengthDays = {for (final e in week) if (e.type == ExerciseType.weightLifting) day(e.date)}.length;

    final advice = <String>[];
    final veryHard = week.where((e) => (e.rpe ?? 0) >= 9).length;
    if (veryHard >= 3) advice.add('$veryHard very hard sessions in 7 days: an easy day or two helps you recover and get stronger.');
    advice.addAll(_repeats(recent));
    final short = targets.minutes - minutes;
    advice.add(short > 0
        ? '${short.ceil()} more active minutes would reach your ${targets.minutes} a week.'
        : 'You met your ${targets.minutes} active minutes this week.');
    if (strengthDays < targets.strengthDays) {
      final more = targets.strengthDays - strengthDays;
      advice.add('$more more strength ${more == 1 ? 'day' : 'days'} would reach your ${targets.strengthDays} a week.');
    }
    return WeeklyGuide(minutes: minutes, strengthDays: strengthDays, targets: targets, advice: advice);
  }

  /// The same exercise done the same way 3 times running without feeling
  /// hard: time to do a little more (progressive overload). At most two.
  static List<String> _repeats(List<ExerciseEntry> recent) {
    final byName = <String, List<ExerciseEntry>>{};
    for (final e in recent) {
      if (e.type == ExerciseType.sport) continue;
      final name = e.exerciseName ?? (e.type == ExerciseType.run ? 'Run' : null);
      if (name != null) (byName[name.toLowerCase()] ??= []).add(e);
    }
    final lines = <String>[];
    for (final entries in byName.values) {
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (entries.length < 3) continue;
      final last = entries.take(3).toList();
      String amount(ExerciseEntry e) => e.amount ?? '';
      final what = amount(last.first);
      if (what.isEmpty || last.any((e) => amount(e) != what) || last.any((e) => (e.rpe ?? 0) >= 7)) continue;
      final name = last.first.exerciseName ?? last.first.type.fallbackName;
      final felt = last.every((e) => e.rpe != null && e.rpe! <= 5) ? ' and it felt easy or moderate' : '';
      final next = last.first.type == ExerciseType.run
          ? 'try a little further or faster'
          : (last.first.weight ?? 0) > 0
              ? 'try a little more weight or a couple more reps'
              : 'try a couple more reps or a harder version';
      lines.add('$name: $what the last 3 times$felt. If it’s getting easy, $next.');
      if (lines.length == 2) break;
    }
    return lines;
  }
}
