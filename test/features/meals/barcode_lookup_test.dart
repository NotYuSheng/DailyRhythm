import 'dart:convert';

import 'package:daily_rhythm/features/meals/data/services/calorie_lookup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('a barcode reads the product, per serving when given', () async {
    late Uri asked;
    final lookup = OpenFoodFactsLookup(MockClient((r) async {
      asked = r.url;
      return http.Response(jsonEncode({
        'status': 1,
        'product': {'product_name': 'Oat bar', 'brands': 'Brand A, Brand B', 'nutriments': {'energy-kcal_serving': 140, 'energy-kcal_100g': 420}},
      }), 200);
    }));
    final m = (await lookup.byBarcode('5 000112 548167'))!;
    expect(asked.path, '/api/v2/product/5000112548167.json', reason: 'only the digits are sent');
    expect((m.name, m.brand, m.kcal, m.basis, m.source), ('Oat bar', 'Brand A', 140.0, 'serving', 'off'));
  });

  test('unknown codes, short codes and products without calories give nothing', () async {
    final unknown = OpenFoodFactsLookup(MockClient((_) async => http.Response(jsonEncode({'status': 0}), 200)));
    expect(await unknown.byBarcode('12345678'), isNull);
    expect(await unknown.byBarcode('123'), isNull);
    final noKcal = OpenFoodFactsLookup(MockClient((_) async => http.Response(jsonEncode({'status': 1, 'product': {'product_name': 'Tea', 'nutriments': {}}}), 200)));
    expect(await noKcal.byBarcode('12345678'), isNull);
  });
}
