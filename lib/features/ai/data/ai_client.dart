import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../meals/data/services/calorie_lookup.dart';
import '../domain/ai_settings.dart';
import 'web_search.dart';

/// Something went wrong talking to the AI: worded for the person.
class AiException implements Exception {
  const AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A food's calories as the AI estimated them.
class AiCalorieEstimate {
  const AiCalorieEstimate({required this.kcal, required this.serving, this.source});

  final double kcal;
  final String serving;

  /// Where the AI found the figure (a website or database); null when it
  /// estimated it itself.
  final String? source;
}

/// Something the model may ask the app to do while answering: the app runs
/// it and hands back the result as text.
class AiTool {
  const AiTool({required this.name, required this.description, required this.parameters, required this.run});

  final String name;
  final String description;

  /// JSON schema of the arguments.
  final Map<String, dynamic> parameters;
  final Future<String> Function(Map<String, dynamic> args) run;

  Map<String, dynamic> toJson() => {
        'type': 'function',
        'function': {'name': name, 'description': description, 'parameters': parameters},
      };
}

/// Talks to an OpenAI-compatible chat completions endpoint. Only what a
/// feature needs is sent (a food's name for calories), never the journal.
///
/// With [foods] or [web] it can look calories up before answering: the
/// model asks, the phone searches, and the results go back to the model.
class AiClient {
  AiClient(this.settings, [http.Client? client, this.foods, this.web]) : _http = client ?? http.Client();

  final AiSettings settings;
  final http.Client _http;

  /// The app's calorie sources (USDA on the phone, Open Food Facts).
  final CalorieLookup? foods;

  /// Web search, when set up in Settings.
  final WebSearch? web;

  /// Look-ups the model may make for one answer before it must reply.
  static const maxToolRounds = 4;

  /// How long one answer may take.
  static const defaultTimeout = Duration(seconds: 45);

  Uri get _endpoint {
    var base = settings.baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return Uri.parse('$base/chat/completions');
  }

  /// One question, one answer. Sampling settings aren't sent: some current
  /// models reject them, and the answers here are short and factual.
  ///
  /// With [tools] the model may ask for look-ups first; each is run and its
  /// result sent back, up to [maxToolRounds] times. A model or server that
  /// doesn't do tools is asked again without them.
  Future<String> complete({required String system, required String user, List<AiTool> tools = const [], Duration timeout = defaultTimeout}) async {
    if (!settings.ready) throw const AiException('Set up the AI assistant in Settings first.');
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': system},
      {'role': 'user', 'content': user},
    ];
    var offered = tools;
    for (var round = 0;; round++) {
      final last = round >= maxToolRounds;
      Map<String, dynamic> message;
      try {
        message = await _send(messages, last ? const [] : offered, timeout);
      } on _Rejected {
        // Most likely no tool support: answer from what it knows.
        if (offered.isEmpty) throw const AiException('The provider answered 400. Check the model name.');
        offered = const [];
        message = await _send(messages, const [], timeout);
      }
      final calls = (message['tool_calls'] as List?)?.whereType<Map>().toList() ?? const [];
      if (calls.isEmpty || offered.isEmpty || last) {
        final text = _text(message['content']);
        if (text.trim().isEmpty) throw const AiException('The answer wasn’t in the expected format.');
        return text.trim();
      }
      messages.add({'role': 'assistant', 'content': message['content'], 'tool_calls': calls});
      for (final call in calls) {
        final fn = call['function'] as Map? ?? const {};
        final tool = offered.where((t) => t.name == fn['name']).firstOrNull;
        String result;
        if (tool == null) {
          result = 'Error: no tool called ${fn['name']}.';
        } else {
          try {
            final raw = fn['arguments'];
            final args = raw is Map ? raw.cast<String, dynamic>() : (raw is String && raw.trim().isNotEmpty ? jsonDecode(raw) as Map<String, dynamic> : <String, dynamic>{});
            result = await tool.run(args);
          } catch (e) {
            result = 'Error: $e';
          }
        }
        messages.add({'role': 'tool', 'tool_call_id': call['id'], 'content': result});
      }
    }
  }

  static String _text(Object? content) =>
      content is String ? content : content is List ? content.map((p) => p is Map ? p['text'] ?? '' : '').join() : '';

  /// One request; the reply's message.
  Future<Map<String, dynamic>> _send(List<Map<String, dynamic>> messages, List<AiTool> tools, Duration timeout) async {
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
              'messages': messages,
              if (tools.isNotEmpty) 'tools': [for (final t in tools) t.toJson()],
            }),
          )
          .timeout(timeout);
    } on FormatException {
      throw const AiException('That address doesn’t look right.');
    } on TimeoutException {
      throw AiException('The AI took longer than ${timeout.inSeconds} seconds to answer. Try again.');
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
    if (response.statusCode == 400 || response.statusCode == 422) throw const _Rejected();
    if (response.statusCode != 200) {
      throw AiException('The provider answered ${response.statusCode}.');
    }
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return (((body['choices'] as List).first as Map)['message'] as Map).cast<String, dynamic>();
    } catch (_) {
      throw const AiException('The answer wasn’t in the expected format.');
    }
  }

  /// Look-ups offered while estimating calories: the app's food databases,
  /// and the web when search is set up.
  List<AiTool> get calorieTools => [
        if (foods case final foods?)
          AiTool(
            name: 'search_food_databases',
            description: 'Search USDA FoodData Central and Open Food Facts for a food. '
                'Returns matches with calories per serving or per 100 g.',
            parameters: const {
              'type': 'object',
              'properties': {'query': {'type': 'string', 'description': 'The food, e.g. "brown rice" or "Milo"'}},
              'required': ['query'],
            },
            run: (args) async {
              final matches = await foods.search('${args['query'] ?? ''}');
              if (matches.isEmpty) return 'No matches.';
              return jsonEncode([
                for (final m in matches.take(8))
                  {
                    'name': m.name,
                    if (m.brand != null) 'brand': m.brand,
                    'kcal': m.kcal.round(),
                    'per': m.basis == 'serving' ? (m.serving ?? 'serving') : m.basis,
                    'source': m.source == 'usda' ? 'USDA FoodData Central' : m.source == 'off' ? 'Open Food Facts' : m.source,
                  },
              ]);
            },
          ),
        if (web case final web?) ...[
          AiTool(
            name: 'web_search',
            description: 'Search the web. Use it to find the officially published calories of a branded, '
                'restaurant, chain or packaged item. Returns titles, links and snippets.',
            parameters: const {
              'type': 'object',
              'properties': {'query': {'type': 'string', 'description': 'e.g. "McDonald\'s Big Mac calories"'}},
              'required': ['query'],
            },
            run: (args) async {
              final results = await web.search('${args['query'] ?? ''}');
              return results.isEmpty ? 'No results.' : jsonEncode([for (final r in results) r.toJson()]);
            },
          ),
          AiTool(
            name: 'read_page',
            description: 'Read the text of a web page from the search results, such as a nutrition page, '
                'when the snippet doesn\'t show the figure.',
            parameters: const {
              'type': 'object',
              'properties': {'url': {'type': 'string'}},
              'required': ['url'],
            },
            run: (args) => fetchPageText(_http, '${args['url'] ?? ''}'),
          ),
        ],
      ];

  /// A short round trip to check the settings work.
  Future<void> test() async {
    await complete(system: 'You are a connection test.', user: 'Reply with the single word OK.');
  }

  /// Calories in one typical serving of [food], or null if the AI says it
  /// isn't a food. Only the name is sent; with look-ups, it's also what
  /// gets searched.
  Future<AiCalorieEstimate?> estimateCalories(String food) async {
    final tools = calorieTools;
    final lookUp = tools.isEmpty
        ? ''
        : 'Before answering, look the figure up when that helps. ${web != null ? 'For a branded, restaurant, chain or packaged item, '
            'find the officially published figure with web_search, preferring the brand\'s own site, and read_page if the snippet '
            'doesn\'t show the number. ' : ''}${foods != null ? 'For a generic food, search_food_databases. ' : ''}'
            'Don\'t look up things that aren\'t food or drink. ';
    final answer = await complete(
      system: 'You find the calories in food and drink. $lookUp'
          'Answer with only a JSON object: '
          '{"kcal": <whole number for one typical serving, or null if it is not food or drink>, '
          '"serving": "<the serving, a few words>", '
          '"source": "<where the figure came from, such as a website\'s name or USDA, or null if you estimated it>"}. No other text.',
      user: food.trim(),
      tools: tools,
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
    final source = json['source'];
    return AiCalorieEstimate(
      kcal: value.roundToDouble(),
      serving: (json['serving'] as String?)?.trim().isNotEmpty == true ? json['serving'] as String : 'one serving',
      source: source is String && source.trim().isNotEmpty && source.trim().toLowerCase() != 'null' && source.trim().toLowerCase() != 'estimate'
          ? source.trim()
          : null,
    );
  }
}

/// A 400 or 422: the server didn't accept the request as sent.
class _Rejected implements Exception {
  const _Rejected();
}
