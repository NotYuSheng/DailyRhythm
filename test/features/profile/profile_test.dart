import 'package:daily_rhythm/features/profile/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 28);

  test('sleep ranges follow age, adults when unknown', () {
    ValueRange r(int? age) => PersonalRanges.sleepFor(age);
    expect([null, 10, 15, 30, 70].map((a) => (r(a).low, r(a).high)), [(7, 9), (9, 12), (8, 10), (7, 9), (7, 8)]);
  });

  test('resting calories by Mifflin–St Jeor, the average when sex is skipped', () {
    const base = Profile(birthYear: 1996, heightCm: 175, weightKg: 70);
    // 10×70 + 6.25×175 − 5×30 = 1643.75
    expect(PersonalRanges.restingKcal(const Profile(birthYear: 1996, heightCm: 175, weightKg: 70, sex: Sex.male), today), 1648.75);
    expect(PersonalRanges.restingKcal(const Profile(birthYear: 1996, heightCm: 175, weightKg: 70, sex: Sex.female), today), 1482.75);
    expect(PersonalRanges.restingKcal(base, today), 1565.75);
    expect(PersonalRanges.restingKcal(const Profile(heightCm: 175, weightKg: 70), today), isNull, reason: 'needs an age');
  });

  test('the calorie range narrows with steps', () {
    const p = Profile(birthYear: 1996, heightCm: 175, weightKg: 70, sex: Sex.male);
    final wide = PersonalRanges.kcalFor(p, today)!;
    expect((wide.low, wide.high), (2000, 2550));
    // 1648.75 × 1.55 = 2555.6, ±10%
    final walking = PersonalRanges.kcalFor(p, today, averageSteps: 8000)!;
    expect((walking.low, walking.high), (2300, 2800));
    expect(PersonalRanges.kcalFor(const Profile(), today), isNull);
  });
}
