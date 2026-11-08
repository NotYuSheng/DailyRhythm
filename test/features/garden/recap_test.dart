import 'package:daily_rhythm/features/garden/domain/garden_day.dart';
import 'package:daily_rhythm/features/garden/domain/plant.dart';
import 'package:daily_rhythm/features/garden/domain/recap.dart';
import 'package:daily_rhythm/features/journal/data/models/journal_entry.dart';
import 'package:flutter_test/flutter_test.dart';

DayLog log(int day, {List<String> tags = const [], double? sleep, int exercises = 0, int? mood, int month = 3}) => DayLog(
      date: DateTime(2026, month, day),
      tagNames: tags,
      sleepHours: sleep,
      sleepLogged: sleep != null,
      exerciseKinds: exercises,
      dayMood: mood,
    );

void main() {
  final march = DateTime(2026, 3);

  MonthRecap recap(List<DayLog> logs, {List<JournalEntry> moments = const [], DateTime? today}) => MonthRecap.from(
        month: march,
        logs: logs,
        moments: moments,
        activityTags: {'Work', 'Study', 'Gym'},
        today: today ?? DateTime(2026, 4, 1),
      );

  test('counts plants, quiet days and species', () {
    final r = recap([
      log(1, tags: ['Work'], mood: 4),
      log(2, tags: ['Work']),
      log(3, exercises: 1),
      log(4),
    ]);
    expect((r.plants, r.quietDays), (3, 1));
    expect(r.species, [(PlantSpecies.cactus, 2), (PlantSpecies.sunflower, 1)]);
  });

  test('top activities count days, and only activity tags', () {
    final r = recap([
      log(1, tags: ['Work', 'Work', 'Takeout']),
      log(2, tags: ['Work', 'Study']),
      log(3, tags: ['Study']),
      log(4, tags: ['Gym']),
    ]);
    expect(r.topActivities, [('Work', 2), ('Study', 2), ('Gym', 1)]);
  });

  test('a month in progress counts only days so far', () {
    final r = recap([for (var d = 1; d <= 31; d++) log(d, mood: 3)], today: DateTime(2026, 3, 10));
    expect((r.days.length, r.plants), (10, 10));
  });

  test('highlights: good moods first, then the most said, only with words', () {
    JournalEntry m(int day, String text, int? mood) => JournalEntry(date: DateTime(2026, 3, day), text: text, mood: mood);
    final r = recap([log(1)], moments: [
      m(1, 'Okay day', 3),
      m(2, 'A long walk by the sea with friends', 3),
      m(3, 'Great news', 5),
      m(4, '', 5),
      m(5, 'Fine', null),
    ]);
    expect(r.highlights.map((e) => e.text), ['Great news', 'A long walk by the sea with friends', 'Okay day']);
    expect(r.momentCount, 5);
  });

  test('bad moments aren\'t highlights, and later moments wait', () {
    JournalEntry m(int day, String text, int? mood) => JournalEntry(date: DateTime(2026, 3, day), text: text, mood: mood);
    final r = recap([log(1)], today: DateTime(2026, 3, 10), moments: [
      m(1, 'Argument at work', 2),
      m(2, 'Nice coffee', null),
      m(20, 'Not yet', 5),
    ]);
    expect(r.highlights.map((e) => e.text), ['Nice coffee']);
    expect(r.momentCount, 2);
  });

}
