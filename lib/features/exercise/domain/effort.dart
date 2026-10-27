import 'dart:math' as math;

/// How hard a day's exercise was, from what was logged: 1 (light) to 5
/// (very hard). Worked out, not rated; rough where entries have no reps.
///
/// Points are about one set of a moderate exercise each: a strength entry
/// counts its sets (one when not given), or its reps over 10 when they are,
/// times how hard the exercise is; a run counts 3 a km; a plank 2 a minute.
/// A watch's intensity minutes count one point per 2 minutes, and the day
/// takes whichever is higher (they're usually the same workout).
class Effort {
  Effort._();

  static const levels = ['Light', 'Easy', 'Moderate', 'Hard', 'Very hard'];

  /// Points that start each level after Light.
  static const cuts = [3.0, 6.0, 10.0, 16.0];

  /// The level from which a day counts as a hard workout.
  static const hard = 4;

  static final _factors = [
    (RegExp(r'burpee|pull ?ups?|chin ?ups?|muscle ?ups?', caseSensitive: false), 1.5),
    (RegExp(r'\bdips?\b|push ?ups?|squat|lunge|jogging|mountain climber', caseSensitive: false), 1.2),
    // A curl into a press is a whole-body lift, not a curl.
    (RegExp(r'curl (?:to|and) (?:overhead|press)', caseSensitive: false), 1.0),
    (RegExp(r'stretch', caseSensitive: false), 0.2),
    (RegExp(r'jumping jack', caseSensitive: false), 0.5),
    (RegExp(r'sit ?ups?|crunch|twist|leg raise|bridge|side bend|curl|raise|plank', caseSensitive: false), 0.7),
  ];
  static final _minutes = RegExp(r'duration_min ([\d.]+)');

  /// How hard an exercise is per set, against a moderate one (1).
  static double factorFor(String name) {
    for (final (pattern, factor) in _factors) {
      if (pattern.hasMatch(name)) return factor;
    }
    return 1;
  }

  /// One logged exercise's points.
  static double entryPoints({required bool run, String? name, int? reps, int? sets, double? km, String? notes, Duration? duration}) {
    if (run) return (km ?? 3) * 3; // a run of unknown length: a short one
    final label = name ?? '';
    final minutes = duration?.inSeconds.toDouble() ?? (double.tryParse(_minutes.firstMatch(notes ?? '')?.group(1) ?? '') ?? 0) * 60;
    if (minutes > 0 && RegExp('plank', caseSensitive: false).hasMatch(label)) return minutes / 60 * 2;
    final count = sets ?? 1;
    return factorFor(label) * (reps == null ? count : math.max(1, reps * count / 10));
  }

  /// The day's points: what was logged, or the watch's intensity minutes
  /// when higher. Intensity minutes alone (a brisk walk) aren't exercise.
  static double dayPoints(double logged, {double? intensityMinutes, bool watchWorkout = false}) {
    if (logged <= 0 && !watchWorkout) return 0;
    return math.max(logged, (intensityMinutes ?? 0) / 2);
  }

  /// 1–5, or null for no exercise.
  static int? levelFor(double points) => points <= 0 ? null : 1 + cuts.where((c) => points >= c).length;

  static String labelFor(int level) => levels[(level - 1).clamp(0, 4)];
}
