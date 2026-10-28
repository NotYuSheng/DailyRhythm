import 'package:daily_rhythm/features/exercise/domain/effort.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an entry counts its sets, or its reps over 10, by how hard it is', () {
    expect(Effort.entryPoints(run: false, name: 'Dumbbell curl to overhead press'), 1, reason: 'one set, moderate');
    expect(Effort.entryPoints(run: false, name: 'Sit ups', reps: 60), closeTo(4.2, 0.01));
    expect(Effort.entryPoints(run: false, name: 'Pull ups', reps: 10, sets: 3), 4.5);
    expect(Effort.entryPoints(run: false, name: 'Jumping jacks', reps: 100), 5);
    expect(Effort.entryPoints(run: false, name: 'Plank', notes: 'duration_min 2'), 4);
    expect(Effort.entryPoints(run: true, km: 5), 15);
  });

  test('a day takes the watch’s intensity minutes when higher, but a walk alone isn’t exercise', () {
    expect(Effort.dayPoints(2, intensityMinutes: 40), 20);
    expect(Effort.dayPoints(8, intensityMinutes: 4), 8);
    expect(Effort.dayPoints(0, intensityMinutes: 60), 0);
    expect(Effort.dayPoints(0, intensityMinutes: 60, watchWorkout: true), 30);
  });

  test('levels from light to very hard', () {
    expect(<double>[0, 1, 3, 6, 10, 16, 40].map(Effort.levelFor), [null, 1, 2, 3, 4, 5, 5]);
    expect(Effort.labelFor(4), 'Hard');
  });

  test('calories burned: METs times weight times time, roughly', () {
    // One moderate set: a minute at 8 METs = 8 × 3.5 × 60 / 200 = 8.4 kcal at 60 kg.
    expect(Effort.kcalBurned(run: false, weightKg: 60, name: 'Dumbbell curl to overhead press'), closeTo(8.4, 0.01));
    expect(Effort.kcalBurned(run: false, weightKg: 60, name: 'Push ups', reps: 30), closeTo(30.24, 0.01));
    expect(Effort.kcalBurned(run: true, weightKg: 60, km: 5), 300);
    expect(Effort.kcalBurned(run: false, weightKg: 60, name: 'Plank', notes: 'duration_min 2'), closeTo(8.4, 0.01));
  });
}
