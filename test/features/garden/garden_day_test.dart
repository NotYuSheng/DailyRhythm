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

  test('sleep sets the size without judging it', () {
    expect([null, 4.0, 5.5, 6.5, 7.5, 9.0].map(GardenDay.sleepLevel), [2, 0, 1, 2, 3, 4]);
    expect(GardenDay.from(log(sleep: 4, sleepLogged: true)).detail, startsWith('Grew from a very short night'));
    expect(GardenDay.from(log(mood: 3)).detail, startsWith('Grew from a night of unknown length'));
  });

  test('movement counts the larger of exercises and workouts, plus steps', () {
    expect(GardenDay.moveCountFor(log(exercises: 2, workouts: 1)), 2);
    expect(GardenDay.moveCountFor(log(workouts: 1, steps: 8000)), 2);
    expect(GardenDay.moveCountFor(log(steps: 15000)), 2);
    expect(GardenDay.from(log(exercises: 9)).plant.move, 4);
  });

  test('a good day mood or moment adds a bloom', () {
    expect(GardenDay.from(log(mood: 3)).plant.flower, isFalse);
    expect(GardenDay.from(log(mood: 4)).plant.flower, isTrue);
    expect(GardenDay.from(log(mood: 3, moments: [2, 5])).plant.flower, isTrue);
  });

  test('a day with nothing logged is an empty pot', () {
    final day = GardenDay.from(log());
    expect(day.plant.logged, isFalse);
    expect(day.title, 'A quiet day');
    expect(GardenDay.from(log(steps: 9000)).plant.logged, isFalse, reason: 'watch data alone isn’t a logged day');
    expect(GardenDay.from(log(sleep: 7)).plant.logged, isFalse, reason: 'nor is watch sleep');
  });

  test('every plant draws in every state', () {
    for (final species in PlantSpecies.values) {
      for (final flower in [false, true]) {
        for (var move = 0; move <= 4; move++) {
          final svg = PlantSvg.plant(PlantSpec(species: species, move: move, sleep: move, flower: flower))!;
          expect(svg, startsWith('<svg'));
          expect(svg, isNot(contains('NaN')));
          expect('<'.allMatches(svg).length, '>'.allMatches(svg).length, reason: '$species $move');
        }
      }
    }
    expect(PlantSvg.plant(const PlantSpec(species: PlantSpecies.fern, logged: false)), isNull);
  });
}
