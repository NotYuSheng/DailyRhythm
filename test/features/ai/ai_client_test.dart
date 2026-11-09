import 'dart:convert';
import 'dart:io';

import 'package:daily_rhythm/features/ai/data/ai_client.dart';
import 'package:daily_rhythm/features/ai/data/ai_settings_repository.dart';
import 'package:daily_rhythm/features/ai/domain/ai_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const settings = AiSettings(enabled: true, provider: AiProvider.openai, baseUrl: 'https://api.example.com/v1/', model: 'small', apiKey: 'sk-test');

  http.Response reply(String content, {int status = 200}) =>
      http.Response(jsonEncode({'choices': [{'message': {'role': 'assistant', 'content': content}}]}), status);

  test('sends an OpenAI-compatible request with only the food name, no sampling settings', () async {
    late http.Request sent;
    final client = AiClient(settings, MockClient((r) async {
      sent = r;
      return reply('{"kcal": 520, "serving": "one bowl"}');
    }));
    final e = (await client.estimateCalories('  Laksa '))!;
    expect((e.kcal, e.serving), (520, 'one bowl'));
    expect(sent.url.toString(), 'https://api.example.com/v1/chat/completions');
    expect(sent.headers['Authorization'], 'Bearer sk-test');
    final body = jsonDecode(sent.body) as Map;
    expect(body['model'], 'small');
    expect((body['messages'] as List).last, {'role': 'user', 'content': 'Laksa'});
    expect(body.containsKey('temperature'), isFalse);
  });

  test('reads JSON wrapped in a sentence or code block; null means not a food', () {
    expect(AiClient.parseCalories('Sure! ```json\n{"kcal": 300, "serving": "a slice"}\n```')!.kcal, 300);
    expect(AiClient.parseCalories('{"kcal": null, "serving": ""}'), isNull);
    expect(() => AiClient.parseCalories('no idea'), throwsA(isA<AiException>()));
    expect(() => AiClient.parseCalories('{"kcal": 99999}'), throwsA(isA<AiException>()), reason: 'implausible');
  });

  test('errors are worded for people', () async {
    Future<String> message(int status) async {
      final client = AiClient(settings, MockClient((_) async => http.Response('{}', status)));
      try {
        await client.test();
        return 'no error';
      } on AiException catch (e) {
        return e.message;
      }
    }

    expect(await message(401), 'The provider refused the API key.');
    expect(await message(404), contains('model name'));
    expect(await message(429), contains('Try again later'));
    expect(await message(500), 'The provider answered 500.');
  });

  test('a self-hosted server needs no key; a cloud one does', () {
    expect(const AiSettings(enabled: true, provider: AiProvider.ollama, baseUrl: 'http://pc.ts.net:11434/v1', model: 'llama3.2').ready, isTrue);
    expect(const AiSettings(enabled: true, provider: AiProvider.openai, baseUrl: 'https://api.openai.com/v1', model: 'x').ready, isFalse);
    expect(settings.copyWith(enabled: false).ready, isFalse, reason: 'off means nothing is sent');
  });

  test('the key is kept in its own file, not with the other settings', () async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('ai_key');
    addTearDown(() => dir.delete(recursive: true));
    final repo = AiSettingsRepository(keyDirectory: () async => dir);
    await repo.save(settings);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().any((k) => prefs.get(k).toString().contains('sk-test')), isFalse);
    expect(File('${dir.path}/${AiSettingsRepository.keyFile}').readAsStringSync(), 'sk-test');
    final loaded = await repo.load();
    expect((loaded.enabled, loaded.model, loaded.apiKey, loaded.baseUrl), (true, 'small', 'sk-test', 'https://api.example.com/v1/'));
    await repo.save(loaded.copyWith(apiKey: ''));
    expect(File('${dir.path}/${AiSettingsRepository.keyFile}').existsSync(), isFalse, reason: 'clearing the key deletes it');
  });
}
