import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/ai_settings.dart';

/// Something went wrong talking to the AI: worded for the person.
class AiException implements Exception {
  const AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A food's calories as the AI estimated them.
class AiCalorieEstimate {
  const AiCalorieEstimate({required this.kcal, required this.serving});

  final double kcal;
  final String serving;
}

/// Talks to an OpenAI-compatible chat completions endpoint. Only what a
/// feature needs is sent (a food's name for calories), never the journal.
class AiClient {
  AiClient(this.settings, [http.Client? client]) : _http = client ?? http.Client();

  final AiSettings settings;
  final http.Client _http;

  Uri get _endpoint {
    var base = settings.baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return Uri.parse('$base/chat/completions');
  }

  /// One question, one answer. Sampling settings aren't sent: some current
  /// models reject them, and the answers here are short and factual.
  Future<String> complete({required String system, required String user}) async {
    if (!settings.ready) throw const AiException('Set up the AI assistant in Settings first.');
    final http.Response response;
    try {
      response = await _http
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              if (settings.apiKey.trim().isNotEmpty) 'Authorization': 'Bearer ${settings.apiKey.trim()}',
            },
            body: jsonEncode({
              'model': settings.model.trim(),
              'messages': [
                {'role': 'system', 'content': system},
                {'role': 'user', 'content': user},
              ],
            }),
          )
          .timeout(const Duration(seconds: 45));
    } on FormatException {
      throw const AiException('That address doesn’t look right.');
    } catch (e) {
      throw AiException('Couldn’t reach ${_endpoint.host}. Check the address and your connection.');
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AiException('The provider refused the API key.');
    }
    if (response.statusCode == 404) {
      throw const AiException('Not found: check the address and the model name.');
    }
    if (response.statusCode == 429) {
      throw const AiException('Too many requests or out of credit. Try again later.');
    }
    if (response.statusCode != 200) {
      throw AiException('The provider answered ${response.statusCode}.');
    }
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = ((body['choices'] as List).first as Map)['message']['content'];
      final text = content is String ? content : content is List ? content.map((p) => p is Map ? p['text'] ?? '' : '').join() : '';
      if (text.trim().isEmpty) throw const FormatException();
      return text.trim();
    } catch (_) {
      throw const AiException('The answer wasn’t in the expected format.');
    }
  }

  /// A short round trip to check the settings work.
  Future<void> test() async {
    await complete(system: 'You are a connection test.', user: 'Reply with the single word OK.');
  }

  /// Calories in one typical serving of [food], or null if the AI says it
  /// isn't a food. Only the name is sent.
  Future<AiCalorieEstimate?> estimateCalories(String food) async {
    final answer = await complete(
      system: 'You estimate calories for food and drink. Answer with only a JSON object: '
          '{"kcal": <whole number for one typical serving, or null if it is not food or drink>, '
          '"serving": "<the serving you assumed, a few words>"}. No other text.',
      user: food.trim(),
    );
    return parseCalories(answer);
  }

  /// The first JSON object in [answer], read leniently (models sometimes
  /// wrap it in a code block or a sentence).
  static AiCalorieEstimate? parseCalories(String answer) {
    final match = RegExp(r'\{[^{}]*\}', dotAll: true).firstMatch(answer);
    if (match == null) throw const AiException('The answer wasn’t in the expected format.');
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(match.group(0)!) as Map<String, dynamic>;
    } catch (_) {
      throw const AiException('The answer wasn’t in the expected format.');
    }
    final kcal = json['kcal'];
    final value = kcal is num ? kcal.toDouble() : double.tryParse('$kcal');
    if (value == null) return null;
    if (value <= 0 || value > 5000) throw const AiException('That estimate doesn’t look right. Type the calories instead.');
    return AiCalorieEstimate(kcal: value.roundToDouble(), serving: (json['serving'] as String?)?.trim().isNotEmpty == true ? json['serving'] as String : 'one serving');
  }
}
