/// Where AI requests go. Every preset speaks the OpenAI-compatible chat
/// completions API, so a self-hosted server works the same way as a cloud
/// provider: only the address changes.
enum AiProvider {
  openai('OpenAI', 'https://api.openai.com/v1', 'gpt-…', true),
  anthropic('Anthropic', 'https://api.anthropic.com/v1', 'claude-opus-5-5', true),
  gemini('Google Gemini', 'https://generativelanguage.googleapis.com/v1beta/openai', 'gemini-…', true),
  openrouter('OpenRouter', 'https://openrouter.ai/api/v1', 'provider/model', true),
  ollama('Ollama (your own)', 'http://localhost:11434/v1', 'llama3.2', false),
  lmStudio('LM Studio (your own)', 'http://localhost:1234/v1', 'the loaded model', false),
  custom('Custom', '', 'model name', false);

  const AiProvider(this.label, this.baseUrl, this.modelHint, this.needsKey);

  final String label;

  /// The provider's address; for a self-hosted one, a starting point to
  /// change to the machine's address.
  final String baseUrl;
  final String modelHint;

  /// Cloud providers need an API key; a server you run usually doesn't.
  final bool needsKey;

  static AiProvider byName(String? name) => values.firstWhere((p) => p.name == name, orElse: () => openai);
}

/// Where the AI looks things up on the web, if anywhere. Search runs on
/// the phone: the model asks, the app searches and hands back the results.
enum SearchProvider {
  none('Off', '', false),
  brave('Brave Search', 'https://api.search.brave.com', true),
  searxng('SearXNG (your own)', 'http://localhost:8080', false);

  const SearchProvider(this.label, this.baseUrl, this.needsKey);

  final String label;
  final String baseUrl;
  final bool needsKey;

  static SearchProvider byName(String? name) => values.firstWhere((p) => p.name == name, orElse: () => none);
}

/// The optional AI connection. Off until the user turns it on; nothing is
/// sent anywhere while it's off.
class AiSettings {
  const AiSettings({
    this.enabled = false,
    this.provider = AiProvider.openai,
    this.baseUrl = '',
    this.model = '',
    this.apiKey = '',
    this.search = SearchProvider.none,
    this.searchUrl = '',
    this.searchKey = '',
  });

  final bool enabled;
  final AiProvider provider;
  final String baseUrl;
  final String model;
  final String apiKey;

  /// Web search the AI may use to find published calories.
  final SearchProvider search;
  final String searchUrl;
  final String searchKey;

  /// Turned on and filled in enough to make a request.
  bool get ready => enabled && baseUrl.trim().isNotEmpty && model.trim().isNotEmpty && (!provider.needsKey || apiKey.trim().isNotEmpty);

  /// Web search is chosen and filled in enough to use.
  bool get searchReady =>
      search != SearchProvider.none && searchUrl.trim().isNotEmpty && (!search.needsKey || searchKey.trim().isNotEmpty);

  AiSettings copyWith({
    bool? enabled,
    AiProvider? provider,
    String? baseUrl,
    String? model,
    String? apiKey,
    SearchProvider? search,
    String? searchUrl,
    String? searchKey,
  }) =>
      AiSettings(
        enabled: enabled ?? this.enabled,
        provider: provider ?? this.provider,
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
        search: search ?? this.search,
        searchUrl: searchUrl ?? this.searchUrl,
        searchKey: searchKey ?? this.searchKey,
      );
}
