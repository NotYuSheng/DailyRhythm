import 'package:daily_rhythm/features/exercise/data/models/exercise_entry.dart';
import 'package:flutter_test/flutter_test.dart';

ExerciseEntry lift({int? sets, int? reps, double? weight}) => ExerciseEntry(
      date: DateTime(2026, 10, 24),
      timestamp: DateTime(2026, 10, 24),
      type: ExerciseType.weightLifting,
      exerciseName: 'Curls',
      sets: sets,
      reps: reps,
      weight: weight,
    );

void main() {
  test('amount shows only what was recorded, never "null"', () {
    expect(lift(reps: 15).amount, '15 reps');
    expect(lift(sets: 3, reps: 12, weight: 20).amount, '3×12 @ 20.0 kg');
    expect(lift().amount, isNull);
    final run = ExerciseEntry(date: DateTime(2026), timestamp: DateTime(2026), type: ExerciseType.run, distance: 5.2);
    expect(run.amount, '5.2 km');
  });
}
