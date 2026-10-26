import 'dart:math' as math;

import 'plant.dart';

/// What was logged on one day, gathered for the garden.
class DayLog {
  DayLog({
    required this.date,
    this.tagNames = const [],
    this.exerciseKinds = 0,
    this.workouts = 0,
    this.steps,
    this.sleepHours,
    this.sleepLogged = false,
    this.dayMood,
    this.momentMoods = const [],
    this.momentCount = 0,
    this.mealCount = 0,
    this.hasCheckin = false,
    this.plantOverride,
    this.routineTags = const {},
  });

  final DateTime date;

  /// Activity tags logged that day (food sources and symptoms included).
  final List<String> tagNames;

  /// Distinct exercises logged in the app.
  final int exerciseKinds;

  /// Workouts recorded by a watch or Health Connect / HealthKit.
  final int workouts;
  final double? steps;
  /// Sleep length from the app's log, or the watch when there is none.
  final double? sleepHours;

  /// Whether sleep was logged in the app; watch data alone doesn't count
  /// as a logged day.
  final bool sleepLogged;
  final int? dayMood;
  final List<int> momentMoods;
  final int momentCount;
  final int mealCount;
  final bool hasCheckin;
  final PlantSpecies? plantOverride;

  /// Tags logged on most recent days, which say little about this one.
  final Set<String> routineTags;

  bool get logged =>
      dayMood != null ||
      sleepLogged ||
      tagNames.isNotEmpty ||
      exerciseKinds > 0 ||
      momentCount > 0 ||
      mealCount > 0 ||
      hasCheckin;
}

/// One day in the garden: its plant and why it looks that way.
class GardenDay {
  GardenDay({
    required this.date,
    required this.plant,
    required this.chosen,
    this.sleepHours,
    this.moveCount = 0,
    this.usual = false,
  });

  final DateTime date;
  final PlantSpec plant;

  /// True when the user picked the plant ("today was mostly…").
  final bool chosen;
  final double? sleepHours;
  final int moveCount;

  /// Only routine tags were logged: an ordinary day rather than a mix.
  final bool usual;

  /// Activity tags for each plant. Food sources and symptoms don't pick a
  /// plant: they say nothing about what the day was about.
  static const tagSpecies = {
    'Exercise': PlantSpecies.sunflower,
    'Intense Exercise': PlantSpecies.sunflower,
    'Nap': PlantSpecies.succulent,
    'Slept Early': PlantSpecies.succulent,
    'Social Event': PlantSpecies.tulip,
    'Family Time': PlantSpecies.tulip,
    'Family Issues': PlantSpecies.tulip,
    'Work': PlantSpecies.cactus,
    'Study': PlantSpecies.fern,
    'Class': PlantSpecies.fern,
    'Test': PlantSpecies.fern,
    'Video Games': PlantSpecies.monstera,
    'Watch Videos': PlantSpecies.monstera,
  };

  /// Words in a tag name that mark a big day.
  static final _bigDay = RegExp(r'trip|travel|holiday|vacation|birthday|wedding|festival|concert', caseSensitive: false);

  /// Share of recent days a tag must appear on to count as routine.
  static const routineShare = 0.6;

  /// The plant a day grows when the user hasn't picked one: a tree for a big
  /// day; otherwise the one kind of activity that stands out. Routine tags
  /// only decide when nothing else does, and each kind counts once however
  /// many of its tags were used, so a kind with more tags can't always win.
  /// When every tag is routine, a day with lots of movement is a sunflower
  /// and one after a long night a succulent. Otherwise more than one kind,
  /// or none, is a sprout: a bit of everything.
  static PlantSpecies speciesFor(DayLog log) {
    if (log.tagNames.any(_bigDay.hasMatch)) return PlantSpecies.tree;
    final distinctive = _kinds(log, routine: false);
    final all = _kinds(log, routine: true);
    if (distinctive.length == 1) return distinctive.single;
    if (distinctive.isEmpty && all.length > 1) {
      // Only routine tags, which every day has: let the day itself decide.
      if (moveCountFor(log) >= 3) return PlantSpecies.sunflower;
      if ((log.sleepHours ?? 0) >= longNight) return PlantSpecies.succulent;
    }
    final pick = distinctive.isNotEmpty ? distinctive : all;
    return pick.length == 1 ? pick.single : PlantSpecies.sprout;
  }

  /// The plant kinds a day's tags (and exercise) point to; with [routine]
  /// false, leaving out tags the user logs on most days.
  static Set<PlantSpecies> _kinds(DayLog log, {required bool routine}) {
    bool keep(String name) => routine || !log.routineTags.contains(name);
    return {
      for (final name in log.tagNames)
        if (keep(name) && tagSpecies[name] != null) tagSpecies[name]!,
      if ((log.exerciseKinds > 0 || log.workouts > 0) && keep('Exercise')) PlantSpecies.sunflower,
    };
  }

  /// Whether only routine tags said anything about the day.
  static bool isUsual(DayLog log) => _kinds(log, routine: false).isEmpty && _kinds(log, routine: true).isNotEmpty;

  /// Hours of sleep that make a routine day a rest day.
  static const longNight = 8.5;

  /// 0–4 from the night's length; unknown counts as a medium night.
  static int sleepLevel(double? hours) {
    if (hours == null) return 2;
    if (hours < 5) return 0;
    if (hours < 6) return 1;
    if (hours < 7) return 2;
    if (hours < 8) return 3;
    return 4;
  }

  /// Exercises or workouts (whichever is more, since a watch workout and a
  /// logged run are usually the same thing), plus a little for many steps.
  static int moveCountFor(DayLog log) {
    final sessions = math.max(log.exerciseKinds, log.workouts);
    final steps = log.steps ?? 0;
    return sessions + (steps >= 12000 ? 2 : steps >= 7500 ? 1 : 0);
  }

  /// Tags on at least [routineShare] of [days] (one tag list per day), or
  /// none when there are fewer than two weeks of tagged days to go on.
  static Set<String> routineTagsFor(Iterable<List<String>> days) {
    final tagged = [for (final d in days) if (d.isNotEmpty) d.toSet()];
    if (tagged.length < 14) return const {};
    final counts = <String, int>{};
    for (final day in tagged) {
      for (final name in day) {
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    return {for (final e in counts.entries) if (e.value >= tagged.length * routineShare) e.key};
  }

  factory GardenDay.from(DayLog log) {
    final move = moveCountFor(log);
    final good = (log.dayMood ?? 0) >= 4 || log.momentMoods.any((m) => m >= 4);
    return GardenDay(
      date: log.date,
      chosen: log.plantOverride != null,
      usual: isUsual(log),
      sleepHours: log.sleepHours,
      moveCount: move,
      plant: PlantSpec(
        species: log.plantOverride ?? speciesFor(log),
        sleep: sleepLevel(log.sleepHours),
        move: math.min(4, move),
        flower: good,
        logged: log.logged,
      ),
    );
  }

  static const _nightWords = ['a very short night', 'a short night', 'a medium night', 'a full night', 'a long night'];

  /// "A sunflower: an exercise day"
  String get title => !plant.logged
      ? 'A quiet day'
      : plant.species == PlantSpecies.sprout && usual && !chosen
          ? 'A sprout: a usual day'
          : 'A ${plant.species.plantName}: ${plant.species.dayWord}';

  /// "Grew from a full night, 2 movement sessions, and bloomed for a good moment."
  String get detail {
    if (!plant.logged) return 'Nothing logged. That’s okay.';
    final night = sleepHours == null ? 'a night of unknown length' : _nightWords[plant.sleep];
    final moves = '$moveCount movement ${moveCount == 1 ? 'session' : 'sessions'}';
    return 'Grew from $night, $moves${plant.flower ? ', and bloomed for a good moment.' : '.'}';
  }
}
