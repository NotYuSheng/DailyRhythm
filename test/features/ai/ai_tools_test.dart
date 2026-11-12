import 'dart:convert';
import 'dart:io';

import 'package:daily_rhythm/features/ai/data/ai_client.dart';
import 'package:daily_rhythm/features/ai/data/ai_settings_repository.dart';
import 'package:daily_rhythm/features/ai/data/web_search.dart';
import 'package:daily_rhythm/features/ai/domain/ai_settings.dart';
import 'package:daily_rhythm/features/meals/data/services/calorie_lookup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Foods extends CalorieLookup {
  final queries = <String>[];

  @override
  Future<List<CalorieMatch>> search(String query) async {
    queries.add(query);
    return const [CalorieMatch(name: 'Rice, white, cooked', kcal: 205, basis: 'serving', serving: '1 cup (158 g)', source: 'usda')];
  }
}

class _Web implements WebSearch {
  final queries = <String>[];

  @override
  Future<List<SearchResult>> search(String query) async {
    queries.add(query);
    return const [SearchResult(title: 'Big Mac nutrition', url: 'https://www.mcdonalds.com/big-mac', snippet: 'Big Mac 550 Cal')];
  }
}

void main() {
  const settings = AiSettings(enabled: true, provider: AiProvider.openai, baseUrl: 'https://api.example.com/v1', model: 'small', apiKey: 'sk-test');

  http.Response message(Map<String, dynamic> m) => http.Response(jsonEncode({'choices': [{'message': m}]}), 200);
  Map<String, dynamic> call(String id, String name, Map<String, dynamic> args) =>
      {'id': id, 'type': 'function', 'function': {'name': name, 'arguments': jsonEncode(args)}};

  test('a quick ask thinks briefly, and a server that refuses that is asked again without it', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = AiClient(
      settings,
      MockClient((r) async {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        bodies.add(body);
        if (body.containsKey('reasoning_effort')) return http.Response('{"error": "unknown field"}', 400);
        return message({'role': 'assistant', 'content': 'ok'});
      }),
    );
    expect(await client.complete(system: 's', user: 'u', quick: true), 'ok');
    expect([for (final b in bodies) b['reasoning_effort']], ['low', null]);
    bodies.clear();
    await client.complete(system: 's', user: 'u');
    expect(bodies.single.containsKey('reasoning_effort'), isFalse, reason: 'only when asked');
  });

  test('the model searches the web, the phone runs it, the answer names the source', () async {
    final bodies = <Map<String, dynamic>>[];
    final web = _Web();
    final client = AiClient(
      settings,
      MockClient((r) async {
        bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
        if (bodies.length == 1) {
          return message({'role': 'assistant', 'content': null, 'tool_calls': [call('c1', 'web_search', {'query': 'Big Mac calories'})]});
        }
        return message({'role': 'assistant', 'content': '{"kcal": 550, "serving": "one burger", "source": "mcdonalds.com"}'});
      }),
      _Foods(),
      web,
    );
    final e = (await client.estimateCalories('Big Mac'))!;
    expect((e.kcal, e.serving, e.source), (550, 'one burger', 'mcdonalds.com'));
    expect(web.queries, ['Big Mac calories']);
    final offered = [for (final t in bodies.first['tools'] as List) t['function']['name']];
    expect(offered, ['search_food_databases', 'web_search', 'read_page']);
    final sent = bodies.last['messages'] as List;
    expect(sent[2]['tool_calls'], isNotEmpty, reason: 'the request for the search goes back');
    expect(sent[3]['role'], 'tool');
    expect(sent[3]['tool_call_id'], 'c1');
    expect(sent[3]['content'], contains('550 Cal'));
  });

  test('food databases are offered without web search, and errors go back to the model', () async {
    final bodies = <Map<String, dynamic>>[];
    final foods = _Foods();
    final client = AiClient(
      settings,
      MockClient((r) async {
        bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
        return switch (bodies.length) {
          1 => message({'role': 'assistant', 'tool_calls': [call('a', 'search_food_databases', {'query': 'rice'}), call('b', 'web_search', {'query': 'x'})]}),
          _ => message({'role': 'assistant', 'content': '{"kcal": 205, "serving": "1 cup", "source": "USDA"}'}),
        };
      }),
      foods,
    );
    expect((await client.estimateCalories('Rice'))!.source, 'USDA');
    expect(foods.queries, ['rice']);
    final sent = bodies.last['messages'] as List;
    expect(sent[3]['content'], contains('USDA FoodData Central'));
    expect(sent[4]['content'], startsWith('Error: no tool'), reason: 'web search isn’t set up');
  });

  test('a model without tool support is asked again without them', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = AiClient(
      settings,
      MockClient((r) async {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        bodies.add(body);
        if (body.containsKey('tools')) return http.Response('{"error": "tools not supported"}', 400);
        return message({'role': 'assistant', 'content': '{"kcal": 300, "serving": "a slice", "source": null}'});
      }),
      _Foods(),
    );
    final e = (await client.estimateCalories('Cake'))!;
    expect((e.kcal, e.source), (300, null));
    expect(bodies.length, 2);
  });

  test('look-ups stop after a few rounds and the model must answer', () async {
    var requests = 0;
    final client = AiClient(
      settings,
      MockClient((r) async {
        requests++;
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        if (!body.containsKey('tools')) return message({'role': 'assistant', 'content': '{"kcal": 100, "serving": "one"}'});
        return message({'role': 'assistant', 'tool_calls': [call('$requests', 'search_food_databases', {'query': 'again'})]});
      }),
      _Foods(),
    );
    expect((await client.estimateCalories('Loop'))!.kcal, 100);
    expect(requests, AiClient.maxToolRounds + 1);
  });

  test('Brave and SearXNG results are read; pages become plain text', () async {
    final brave = BraveSearch('https://api.search.brave.com/', 'bk', MockClient((r) async {
      expect(r.url.path, '/res/v1/web/search');
      expect(r.headers['X-Subscription-Token'], 'bk');
      return http.Response(jsonEncode({'web': {'results': [{'title': '<strong>Milo</strong>', 'url': 'https://milo.com', 'description': 'Milo 120 kcal'}]}}), 200);
    }));
    final b = (await brave.search('milo calories')).single;
    expect((b.title, b.snippet), ('Milo', 'Milo 120 kcal'));

    final searx = SearxngSearch('http://pc.ts.net:8080', MockClient((r) async {
      expect(r.url.queryParameters['format'], 'json');
      return http.Response(jsonEncode({'results': [{'title': 'Kaya toast', 'url': 'https://a.sg', 'content': '300 kcal'}]}), 200);
    }));
    expect((await searx.search('kaya toast')).single.snippet, '300 kcal');

    expect(htmlToText('<html><head><title>x</title></head><body><script>var a=1;</script><p>Energy&nbsp;550&#32;kcal</p><table><tr><td>Fat</td><td>30 g</td></tr></table></body></html>'),
        'Energy 550 kcal\nFat | 30 g |');
    final page = MockClient((r) async => http.Response('<p>${'a' * 50}</p>', 200, headers: {'content-type': 'text/html'}));
    expect(await fetchPageText(page, 'https://x.com', limit: 10), '${'a' * 10} …');
    expect(() => fetchPageText(page, 'file:///etc/passwd'), throwsException);
  });

  test('search is ready only when filled in; its key gets a file of its own', () async {
    expect(settings.copyWith(search: SearchProvider.brave, searchUrl: 'https://api.search.brave.com').searchReady, isFalse);
    expect(settings.copyWith(search: SearchProvider.searxng, searchUrl: 'http://pc.ts.net:8080').searchReady, isTrue);
    expect(WebSearch.of(settings), isNull);

    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('ai_search_key');
    addTearDown(() => dir.delete(recursive: true));
    final repo = AiSettingsRepository(keyDirectory: () async => dir);
    await repo.save(settings.copyWith(search: SearchProvider.brave, searchUrl: 'https://api.search.brave.com', searchKey: 'bk-1'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().any((k) => prefs.get(k).toString().contains('bk-1')), isFalse);
    expect(File('${dir.path}/${AiSettingsRepository.searchKeyFile}').readAsStringSync(), 'bk-1');
    final loaded = await repo.load();
    expect((loaded.search, loaded.searchKey, loaded.searchReady), (SearchProvider.brave, 'bk-1', true));
  });
}
