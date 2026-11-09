import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/ai_settings.dart';

/// One search result: where it is and what it says.
class SearchResult {
  const SearchResult({required this.title, required this.url, required this.snippet});

  final String title;
  final String url;
  final String snippet;

  Map<String, String> toJson() => {'title': title, 'url': url, 'snippet': snippet};
}

/// Web search the AI can ask for. The phone does the searching, so the
/// search service sees the query and nothing else.
abstract class WebSearch {
  Future<List<SearchResult>> search(String query);

  /// The search service for [settings], or null when search is off.
  static WebSearch? of(AiSettings settings, [http.Client? client]) {
    if (!settings.searchReady) return null;
    final c = client ?? http.Client();
    return switch (settings.search) {
      SearchProvider.brave => BraveSearch(settings.searchUrl, settings.searchKey, c),
      SearchProvider.searxng => SearxngSearch(settings.searchUrl, c),
      SearchProvider.none => null,
    };
  }
}

String _trimBase(String url) {
  var base = url.trim();
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  return base;
}

String _clean(Object? text) => htmlToText('${text ?? ''}');

/// Brave Search API (needs a key from api-dashboard.search.brave.com).
class BraveSearch implements WebSearch {
  BraveSearch(this.baseUrl, this.key, this._http);

  final String baseUrl;
  final String key;
  final http.Client _http;

  @override
  Future<List<SearchResult>> search(String query) async {
    final uri = Uri.parse('${_trimBase(baseUrl)}/res/v1/web/search').replace(queryParameters: {'q': query, 'count': '6'});
    final response = await _http
        .get(uri, headers: {'Accept': 'application/json', 'X-Subscription-Token': key.trim()})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('Brave Search answered ${response.statusCode}');
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final results = (body['web'] as Map?)?['results'] as List? ?? const [];
    return [
      for (final r in results.whereType<Map>())
        SearchResult(
          title: _clean(r['title']),
          url: '${r['url'] ?? ''}',
          snippet: [_clean(r['description']), ...((r['extra_snippets'] as List?) ?? const []).map(_clean)].join(' … '),
        ),
    ];
  }
}

/// A SearXNG server you run (its JSON output must be turned on).
class SearxngSearch implements WebSearch {
  SearxngSearch(this.baseUrl, this._http);

  final String baseUrl;
  final http.Client _http;

  @override
  Future<List<SearchResult>> search(String query) async {
    final uri = Uri.parse('${_trimBase(baseUrl)}/search').replace(queryParameters: {'q': query, 'format': 'json'});
    final response = await _http.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 15));
    if (response.statusCode == 403) throw Exception('SearXNG refused JSON: turn on the json format in its settings');
    if (response.statusCode != 200) throw Exception('SearXNG answered ${response.statusCode}');
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final results = body['results'] as List? ?? const [];
    return [
      for (final r in results.whereType<Map>().take(6))
        SearchResult(title: _clean(r['title']), url: '${r['url'] ?? ''}', snippet: _clean(r['content'])),
    ];
  }
}

/// A web page's readable text, for the AI to find a figure in. Only
/// public http(s) pages; at most [limit] characters.
Future<String> fetchPageText(http.Client client, String url, {int limit = 8000}) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !(uri.isScheme('https') || uri.isScheme('http')) || uri.host.isEmpty) {
    throw Exception('Not a web address');
  }
  final response = await client
      .get(uri, headers: {'User-Agent': 'DailyRhythm/1.0 (calorie lookup; github.com/NotYuSheng/DailyRhythm)', 'Accept': 'text/html,text/plain'})
      .timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) throw Exception('The page answered ${response.statusCode}');
  final type = response.headers['content-type'] ?? '';
  if (type.isNotEmpty && !type.contains('html') && !type.contains('text') && !type.contains('json')) {
    throw Exception('Not a text page ($type)');
  }
  final text = htmlToText(utf8.decode(response.bodyBytes, allowMalformed: true));
  return text.length <= limit ? text : '${text.substring(0, limit)} …';
}

/// HTML to plain text: scripts, styles and tags dropped, common entities
/// decoded, whitespace collapsed. Rough, but enough to read a figure.
String htmlToText(String html) {
  var s = html
      .replaceAll(RegExp(r'<(script|style|noscript|svg|head)\b[^>]*>.*?</\1>', caseSensitive: false, dotAll: true), ' ')
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ')
      .replaceAll(RegExp(r'<(br|/p|/div|/li|/tr|/h\d)\b[^>]*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</t[dh]>', caseSensitive: false), ' | ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ');
  const entities = {'&nbsp;': ' ', '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'", '&apos;': "'"};
  entities.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)));
  return s.replaceAll(RegExp(r'[ \t\r\f]+'), ' ').replaceAll(RegExp(r'\s*\n\s*'), '\n').trim();
}
