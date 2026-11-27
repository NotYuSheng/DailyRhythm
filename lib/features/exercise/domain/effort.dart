import 'dart:math' as math;

/// How hard a day's exercise was, from what was logged: 1 (light) to 5
/// (very hard). Worked out, not rated; rough where entries have no reps.
///
/// Points are about one set of a moderate exercise each: a strength entry
/// counts its sets (one when not given), or its reps over 10 when they are,
/// times how hard the exercise is; a run counts 3 a km; a plank 2 a minute.
/// A watch's intensity minutes count one point per 2 minutes, and the day
/// takes whichever is higher (they're usually the same workout). A sport
/// counts its minutes by how hard it usually is: an hour of badminton is
/// about a 5 km run.
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

  /// How hard sports usually are, in METs (from the Compendium of Physical
  /// Activities, rounded); first match wins.
  static final _sports = [
    (RegExp(r'rugby|hockey|ultimate', caseSensitive: false), 8.0),
    (RegExp(r'box|muay|kickbox|mma|martial|judo|karate|taekwondo|jiu', caseSensitive: false), 7.5),
    (RegExp(r'tennis|squash|soccer|football|futsal|cycl|bike|spin|skat|ski', caseSensitive: false), 7.0),
    (RegExp(r'basketball|netball', caseSensitive: false), 6.5),
    (RegExp(r'swim|hik|trek|row|kayak|padel|climb|boulder', caseSensitive: false), 6.0),
    (RegExp(r'badminton', caseSensitive: false), 5.5),
    (RegExp(r'danc|zumba|cricket', caseSensitive: false), 5.0),
    (RegExp(r'pickleball|volleyball|frisbee|dodgeball|table tennis|ping ?pong|bowling', caseSensitive: false), 4.0),
    (RegExp(r'golf|walk|surf', caseSensitive: false), 3.5),
    (RegExp(r'yoga|pilates|tai chi', caseSensitive: false), 3.0),
  ];

  /// How hard a sport usually is, in METs; a moderate one when unknown.
  /// Table tennis is checked before tennis.
  static double sportMets(String? name) {
    final n = name ?? '';
    if (RegExp(r'table tennis|ping ?pong', caseSensitive: false).hasMatch(n)) return 4.0;
    for (final (pattern, mets) in _sports) {
      if (pattern.hasMatch(n)) return mets;
    }
    return 5.5;
  }

  /// Minutes of a sport, or an hour when not given.
  static double _sportMinutes(Duration? duration) =>
      duration == null || duration.inSeconds <= 0 ? 60 : duration.inSeconds / 60;

  /// How hard an exercise is per set, against a moderate one (1).
  static double factorFor(String name) {
    for (final (pattern, factor) in _factors) {
      if (pattern.hasMatch(name)) return factor;
    }
    return 1;
  }

  /// One logged exercise's points.
  static double entryPoints({
    required bool run,
    bool sport = false,
    String? name,
    int? reps,
    int? sets,
    double? km,
    String? notes,
    Duration? duration,
  }) {
    if (run) return (km ?? 3) * 3; // a run of unknown length: a short one
    // A 5 km run, about 30 minutes at 10 METs, is 15 points.
    if (sport) return sportMets(name) * _sportMinutes(duration) / 20;
    if (_plankMinutes(name, notes, duration) case final minutes?) return minutes * 2;
    final count = sets ?? 1;
    return factorFor(name ?? '') * (reps == null ? count : math.max(1, reps * count / 10));
  }

  /// Calories burned by one logged exercise, roughly: METs × weight × time
  /// (kcal a minute = METs × 3.5 × kg ÷ 200). A set is about a minute of
  /// vigorous work (8 METs), scaled by reps and difficulty as for points;
  /// a run about 1 kcal per kg per km; a plank 4 METs a minute.
  static double kcalBurned({
    required bool run,
    bool sport = false,
    required double weightKg,
    String? name,
    int? reps,
    int? sets,
    double? km,
    String? notes,
    Duration? duration,
  }) {
    double perMinute(double mets) => mets * 3.5 * weightKg / 200;
    if (run) return (km ?? 3) * weightKg;
    if (sport) return _sportMinutes(duration) * perMinute(sportMets(name));
    if (_plankMinutes(name, notes, duration) case final minutes?) return minutes * perMinute(4);
    return entryPoints(run: false, name: name, reps: reps, sets: sets) * perMinute(8);
  }

  /// A timed plank's minutes (from its duration or a "duration_min" note).
  static double? _plankMinutes(String? name, String? notes, Duration? duration) {
    if (!RegExp('plank', caseSensitive: false).hasMatch(name ?? '')) return null;
    final minutes = duration == null
        ? double.tryParse(_minutes.firstMatch(notes ?? '')?.group(1) ?? '')
        : duration.inSeconds / 60;
    return minutes == null || minutes <= 0 ? null : minutes;
  }

  /// Weight to assume when the profile has none.
  static const defaultWeightKg = 70.0;

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
