import 'package:daily_rhythm/features/exercise/data/models/exercise_entry.dart';
import 'package:daily_rhythm/features/exercise/domain/weekly_guide.dart';
import 'package:flutter_test/flutter_test.dart';

ExerciseEntry _run(int day, {double km = 5, int minutes = 30, int? rpe}) => ExerciseEntry(
      date: DateTime(2026, 11, day),
      timestamp: DateTime(2026, 11, day, 7),
      type: ExerciseType.run,
      runType: RunType.flat,
      distance: km,
      duration: Duration(minutes: minutes),
      rpe: rpe,
    );

ExerciseEntry _pushups(int day, {int reps = 20, int? rpe}) => ExerciseEntry(
      date: DateTime(2026, 11, day),
      timestamp: DateTime(2026, 11, day, 19),
      type: ExerciseType.weightLifting,
      exerciseName: 'Push Ups',
      equipmentType: EquipmentType.bodyweight,
      reps: reps,
      sets: 3,
      rpe: rpe,
    );

void main() {
  test('minutes are moderate-equivalent: a run counts double, an easy set half', () {
    expect(WeeklyGuide.minutesOf(_run(1)), 60);
    expect(WeeklyGuide.minutesOf(_pushups(1)), 6);
    expect(WeeklyGuide.minutesOf(_pushups(1, rpe: 7)), 12, reason: 'felt hard');
    expect(WeeklyGuide.minutesOf(_pushups(1, rpe: 3)), 3, reason: 'felt easy');
    final badminton = ExerciseEntry(
        date: DateTime(2026, 11, 1), timestamp: DateTime(2026, 11, 1), type: ExerciseType.sport, exerciseName: 'Badminton', duration: const Duration(hours: 1));
    expect(WeeklyGuide.minutesOf(badminton), 60, reason: 'moderate at 5.5 METs');
  });

  test('the week against the targets, with what would reach them', () {
    final week = [_run(24), _pushups(25)];
    final g = WeeklyGuide.from(week: week, recent: week);
    expect((g.minutes, g.strengthDays), (66, 1));
    expect(g.advice, ['84 more active minutes would reach your 150 a week.', '1 more strength day would reach your 2 a week.']);

    final met = WeeklyGuide.from(week: week, recent: week, targets: const WeeklyTargets(minutes: 60, strengthDays: 1));
    expect(met.advice, ['You met your 60 active minutes this week.']);
  });

  test('a watch’s intensity minutes count when higher than what was logged', () {
    final g = WeeklyGuide.from(week: [_pushups(25)], recent: const [], watchMinutes: {DateTime(2026, 11, 25): 40, DateTime(2026, 11, 26): 20});
    expect(g.minutes, 60);
  });

  test('the same sets 3 times running, not felt as hard, suggests a little more', () {
    final recent = [_pushups(10), _pushups(14, rpe: 5), _pushups(20, rpe: 4)];
    final g = WeeklyGuide.from(week: const [], recent: recent);
    expect(g.advice.first, 'Push Ups: 3×20 the last 3 times. If it’s getting easy, try a couple more reps or a harder version.');

    final easy = WeeklyGuide.from(week: const [], recent: [_pushups(10, rpe: 3), _pushups(14, rpe: 5), _pushups(20, rpe: 4)]);
    expect(easy.advice.first, contains('and it felt easy or moderate'));

    final hard = WeeklyGuide.from(week: const [], recent: [_pushups(10), _pushups(14), _pushups(20, rpe: 8)]);
    expect(hard.advice.first, isNot(startsWith('Push Ups')), reason: 'still felt hard');
    final grew = WeeklyGuide.from(week: const [], recent: [_pushups(10), _pushups(14), _pushups(20, reps: 22)]);
    expect(grew.advice.first, isNot(startsWith('Push Ups')), reason: 'already doing more');
  });

  test('several very hard sessions suggest an easy day', () {
    final week = [_run(23, rpe: 9), _run(24, rpe: 10), _run(26, rpe: 9)];
    expect(WeeklyGuide.from(week: week, recent: week).advice.first, startsWith('3 very hard sessions in 7 days'));
  });
}
