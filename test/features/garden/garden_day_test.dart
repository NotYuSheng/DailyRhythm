import 'package:daily_rhythm/features/garden/domain/garden_day.dart';
import 'package:daily_rhythm/features/garden/domain/plant.dart';
import 'package:flutter_test/flutter_test.dart';

DayLog log({
  List<String> tags = const [],
  int exercises = 0,
  int workouts = 0,
  double? steps,
  double? sleep,
  bool sleepLogged = false,
  int? mood,
  List<int> moments = const [],
  PlantSpecies? override,
  Set<String> routine = const {},
  int? effort,
}) =>
    DayLog(
      date: DateTime(2026, 10, 20),
      tagNames: tags,
      exerciseKinds: exercises,
      workouts: workouts,
      steps: steps,
      sleepHours: sleep,
      sleepLogged: sleepLogged,
      dayMood: mood,
      effort: effort,
      momentMoods: moments,
      momentCount: moments.length,
      plantOverride: override,
      routineTags: routine,
    );

void main() {
  group('species', () {
    test('comes from the one kind of activity tagged', () {
      expect(GardenDay.speciesFor(log(tags: ['Work'])), PlantSpecies.cactus);
      expect(GardenDay.speciesFor(log(tags: ['Study', 'Class', 'Test'])), PlantSpecies.fern);
      expect(GardenDay.speciesFor(log(tags: ['Video Games', 'Watch Videos', 'Takeout'])), PlantSpecies.monstera);
      expect(GardenDay.speciesFor(log(tags: ['Family Time'])), PlantSpecies.tulip);
      expect(GardenDay.speciesFor(log(tags: ['Nap'])), PlantSpecies.succulent);
    });

    test('is a sprout for several kinds or no activity tags', () {
      expect(GardenDay.speciesFor(log(tags: ['Work', 'Study'])), PlantSpecies.sprout);
      expect(GardenDay.speciesFor(log(tags: ['Video Games', 'Watch Videos', 'Work'])), PlantSpecies.sprout,
          reason: 'a kind with two tags doesn\u2019t outvote one with one');
      expect(GardenDay.speciesFor(log(tags: ['Takeout', 'Headache'])), PlantSpecies.sprout);
      expect(GardenDay.speciesFor(log()), PlantSpecies.sprout);
    });

    test('logged exercise counts as an exercise tag', () {
      expect(GardenDay.speciesFor(log(exercises: 3)), PlantSpecies.sunflower);
      expect(GardenDay.speciesFor(log(workouts: 1, tags: ['Work'])), PlantSpecies.sprout);
    });

    test('what stands out beats routine', () {
      const routine = {'Video Games', 'Watch Videos', 'Exercise', 'Work', 'Study'};
      final everyday = ['Video Games', 'Watch Videos', 'Exercise', 'Work', 'Study'];
      expect(GardenDay.speciesFor(log(tags: everyday, routine: routine)), PlantSpecies.sprout);
      expect(GardenDay.speciesFor(log(tags: [...everyday, 'Social Event'], routine: routine)), PlantSpecies.tulip);
      expect(GardenDay.speciesFor(log(tags: [...everyday, 'Intense Exercise'], routine: routine)), PlantSpecies.sunflower);
      expect(GardenDay.speciesFor(log(tags: ['Work'], routine: routine)), PlantSpecies.cactus,
          reason: 'routine still decides when it\u2019s all there is');
    });

    test('a day of only routine tags is chosen by its movement or its night', () {
      const routine = {'Video Games', 'Watch Videos', 'Exercise', 'Work', 'Study'};
      const everyday = ['Video Games', 'Watch Videos', 'Exercise', 'Work', 'Study'];
      expect(GardenDay.speciesFor(log(tags: everyday, routine: routine, exercises: 1, steps: 13000)), PlantSpecies.sunflower);
      expect(GardenDay.speciesFor(log(tags: everyday, routine: routine, sleep: 9)), PlantSpecies.succulent);
      expect(GardenDay.speciesFor(log(tags: everyday, routine: routine, sleep: 7)), PlantSpecies.sprout);
      expect(GardenDay.from(log(tags: everyday, routine: routine, sleep: 7)).title, 'A sprout: a usual day');
      expect(GardenDay.from(log(tags: ['Work', 'Study'], sleep: 7)).title, 'A sprout: a bit of everything');
      expect(GardenDay.from(log(tags: [...everyday, 'Hawker'], routine: routine, sleep: 7)).title, 'A sprout: a usual day',
          reason: 'a tag that picks no plant doesn\u2019t make the day a mix');
    });

    test('routine tags are those on most recent days, given two weeks of history', () {
      final days = [
        for (var i = 0; i < 20; i++) ['Work', if (i < 12) 'Study', if (i == 3) 'Nap'],
      ];
      expect(GardenDay.routineTagsFor(days), {'Work', 'Study'});
      expect(GardenDay.routineTagsFor(days.take(10)), isEmpty);
    });

    test('a trip or birthday is a big day', () {
      expect(GardenDay.speciesFor(log(tags: ['Work', 'Work Trip'])), PlantSpecies.tree);
      expect(GardenDay.speciesFor(log(tags: ['Birthday'])), PlantSpecies.tree);
    });

    test('the user’s pick wins', () {
      final day = GardenDay.from(log(tags: ['Work'], override: PlantSpecies.tulip));
      expect((day.plant.species, day.chosen), (PlantSpecies.tulip, true));
    });
  });

  test('a hard workout grows a sunflower even when exercise is routine', () {
    const routine = {'Exercise', 'Work'};
    final easy = log(tags: ['Exercise', 'Work'], exercises: 1, routine: routine, effort: 1);
    final hard = log(tags: ['Exercise', 'Work'], exercises: 3, routine: routine, effort: 4);
    expect(GardenDay.speciesFor(easy), isNot(PlantSpecies.sunflower));
    expect(GardenDay.speciesFor(hard), PlantSpecies.sunflower);
    expect(GardenDay.from(hard).detail, 'From a hard workout.');
  });

  test('the detail says why the day grew its plant', () {
    expect(GardenDay.from(log(tags: ['Work'])).detail, 'From Work.');
    expect(GardenDay.from(log(tags: ['Study', 'Class'])).detail, 'From Study and Class.');
    expect(GardenDay.from(log(tags: ['Work', 'Study'])).detail, 'A mix: Work and Study.');
    expect(GardenDay.from(log(exercises: 1)).detail, 'From exercise.');
    expect(GardenDay.from(log(tags: ['Birthday'])).detail, 'From Birthday.');
    expect(GardenDay.from(log(mood: 3)).detail, 'No one thing stood out.');
    expect(GardenDay.from(log(tags: ['Work'], override: PlantSpecies.tulip)).detail, 'You picked this plant.');
    expect(GardenDay.from(log()).detail, 'Nothing logged. That’s okay.');
  });

  test('movement counts the larger of exercises and workouts, plus steps', () {
    expect(GardenDay.moveCountFor(log(exercises: 2, workouts: 1)), 2);
    expect(GardenDay.moveCountFor(log(workouts: 1, steps: 8000)), 2);
    expect(GardenDay.moveCountFor(log(steps: 15000)), 2);
  });

  test('a plant shows only its kind of day, not sleep, movement or mood', () {
    final quiet = GardenDay.from(log(tags: ['Work'], mood: 1, sleep: 4, sleepLogged: true));
    final full = GardenDay.from(log(tags: ['Work'], mood: 5, sleep: 9, sleepLogged: true, exercises: 0, steps: 15000));
    expect(quiet.plant, full.plant);
    expect(PlantSvg.plant(quiet.plant), PlantSvg.plant(full.plant));
  });

  test('a day with nothing logged is an empty pot', () {
    final day = GardenDay.from(log());
    expect(day.plant.logged, isFalse);
    expect(day.title, 'A quiet day');
    expect(GardenDay.from(log(steps: 9000)).plant.logged, isFalse, reason: 'watch data alone isn’t a logged day');
    expect(GardenDay.from(log(sleep: 7)).plant.logged, isFalse, reason: 'nor is watch sleep');
  });

  test('every plant draws', () {
    for (final species in PlantSpecies.values) {
      final svg = PlantSvg.plant(PlantSpec(species: species))!;
      expect(svg, startsWith('<svg'));
      expect(svg, isNot(contains('NaN')));
      expect('<'.allMatches(svg).length, '>'.allMatches(svg).length, reason: '$species');
    }
    expect(PlantSvg.plant(const PlantSpec(species: PlantSpecies.fern, logged: false)), isNull);
  });
}
