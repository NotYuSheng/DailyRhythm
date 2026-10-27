/// Sex for the calorie formula; null leaves it out (the average is used).
enum Sex {
  female('Female'),
  male('Male');

  const Sex(this.label);

  final String label;

  static Sex? byName(String? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// What the user told us about themselves, to show typical ranges for
/// them. Every field is optional; it stays on the device.
class Profile {
  const Profile({this.birthYear, this.heightCm, this.weightKg, this.sex});

  final int? birthYear;
  final double? heightCm;
  final double? weightKg;
  final Sex? sex;

  bool get isEmpty => birthYear == null && heightCm == null && weightKg == null && sex == null;

  /// Age this year (a year of precision is plenty for these ranges).
  int? ageIn(DateTime today) => birthYear == null ? null : today.year - birthYear!;
}

/// A typical range, low to high.
class ValueRange {
  const ValueRange(this.low, this.high);

  final double low;
  final double high;

  bool contains(double v) => v >= low && v <= high;
}

/// Typical ranges from a profile: reference points shown beside the
/// user's numbers, not goals.
class PersonalRanges {
  PersonalRanges._();

  /// Hours of sleep recommended for an age (US National Sleep Foundation
  /// and AASM); adults when the age isn't known.
  static ValueRange sleepFor(int? age) => switch (age) {
        null => const ValueRange(7, 9),
        < 13 => const ValueRange(9, 12),
        < 18 => const ValueRange(8, 10),
        < 65 => const ValueRange(7, 9),
        _ => const ValueRange(7, 8),
      };

  /// Calories burned at rest a day (Mifflin–St Jeor), or null without
  /// weight, height and age. Without a sex, the two formulas' average.
  static double? restingKcal(Profile p, DateTime today) {
    final age = p.ageIn(today);
    if (p.weightKg == null || p.heightCm == null || age == null) return null;
    final base = 10 * p.weightKg! + 6.25 * p.heightCm! - 5 * age;
    return base +
        switch (p.sex) {
          Sex.male => 5,
          Sex.female => -161,
          null => -78,
        };
  }

  /// How much a day's movement adds on top of resting, from average steps.
  static double activityFactor(double steps) => switch (steps) {
        < 5000 => 1.2,
        < 7500 => 1.375,
        < 10000 => 1.55,
        _ => 1.725,
      };

  /// Typical calories a day: resting times activity, give or take 10%.
  /// Without step data, the range spans light to moderate activity.
  static ValueRange? kcalFor(Profile p, DateTime today, {double? averageSteps}) {
    final resting = restingKcal(p, today);
    if (resting == null) return null;
    double round(double v) => (v / 50).round() * 50.0;
    if (averageSteps == null) return ValueRange(round(resting * 1.2), round(resting * 1.55));
    final need = resting * activityFactor(averageSteps);
    return ValueRange(round(need * 0.9), round(need * 1.1));
  }
}
