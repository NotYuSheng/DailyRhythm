import 'dart:convert';
import 'dart:io';

import 'package:daily_rhythm/features/meals/data/services/calorie_lookup.dart';
import 'package:daily_rhythm/features/meals/data/services/usda_lookup.dart';
import 'package:flutter_test/flutter_test.dart';

class _Offline implements CalorieLookup {
  @override
  Future<List<CalorieMatch>> search(String query) async => throw Exception('no connection');
  @override
  Future<CalorieMatch?> byBarcode(String code) async => null;
}

class _Online implements CalorieLookup {
  @override
  Future<List<CalorieMatch>> search(String query) async => [const CalorieMatch(name: 'Apple pie bar', kcal: 220, basis: 'serving', source: 'off')];
  @override
  Future<CalorieMatch?> byBarcode(String code) async => null;
}

void main() {
  final sample = UsdaLookup(() async => jsonEncode([
        {'n': 'Babyfood, apples, dessert', 'k': 70, 'p': [['1 jar', 113]]},
        {'n': 'Apples, raw, with skin', 'k': 52, 'p': [['1 medium (3" dia)', 182], ['1 cup, sliced', 109]]},
        {'n': 'Apple juice, canned', 'k': 46},
      ]));

  test('finds by words, plurals too, best match first, per portion when there is one', () async {
    final found = await sample.search('apple');
    expect(found.first.name, 'Apples, raw, with skin');
    expect((found.first.kcal, found.first.basis, found.first.serving, found.first.source), (95.0, 'serving', '1 medium (3" dia) (182 g)', 'usda'));
    expect(found.firstWhere((m) => m.name.startsWith('Apple juice')).basis, '100 g', reason: 'no portion: per 100 g');
    expect(await sample.search('apple raw'), hasLength(1));
    expect(await sample.search('durian'), isEmpty);
  });

  test('offline results stay when the online search fails; both show when online', () async {
    final offline = await CombinedLookup(sample, _Offline()).search('apple');
    expect(offline.every((m) => m.source == 'usda'), isTrue);
    final online = await CombinedLookup(sample, _Online()).search('apple');
    expect(online.last.source, 'off');
    expect(() => CombinedLookup(sample, _Offline()).search('durian'), throwsException, reason: 'nothing at all is an error');
  });

  test('the bundled file loads and finds everyday foods', () async {
    final usda = UsdaLookup(() async => File('assets/data/usda_foods.json').readAsString());
    for (final (query, expected) in [('banana', 'Bananas, raw'), ('egg', 'Egg'), ('broccoli', 'Broccoli')]) {
      final found = await usda.search(query);
      expect(found, isNotEmpty, reason: query);
      expect(found.take(5).map((m) => m.name), anyElement(startsWith(expected)), reason: query);
    }
  });
}
