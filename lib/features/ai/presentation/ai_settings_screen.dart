import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../data/ai_client.dart';
import '../data/ai_providers.dart';
import '../domain/ai_settings.dart';

/// Connects an AI model of the user's choosing: a cloud provider with their
/// own key, or a server they run themselves. Off by default.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  final _key = TextEditingController();
  final _searchUrl = TextEditingController();
  final _searchKey = TextEditingController();
  var _search = SearchProvider.none;
  var _showSearchKey = false;
  var _enabled = false;
  var _provider = AiProvider.openai;
  var _loaded = false;
  var _showKey = false;
  var _testing = false;
  String? _testResult;
  var _testOk = false;

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _key.dispose();
    _searchUrl.dispose();
    _searchKey.dispose();
    super.dispose();
  }

  void _fill(AiSettings s) {
    _enabled = s.enabled;
    _provider = s.provider;
    _baseUrl.text = s.baseUrl.isEmpty ? s.provider.baseUrl : s.baseUrl;
    _model.text = s.model;
    _key.text = s.apiKey;
    _search = s.search;
    _searchUrl.text = s.searchUrl.isEmpty ? s.search.baseUrl : s.searchUrl;
    _searchKey.text = s.searchKey;
    _loaded = true;
  }

  AiSettings get _current => AiSettings(
        enabled: _enabled,
        provider: _provider,
        baseUrl: _baseUrl.text,
        model: _model.text,
        apiKey: _key.text,
        search: _search,
        searchUrl: _searchUrl.text,
        searchKey: _searchKey.text,
      );

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await ref.read(aiSettingsProvider.notifier).save(_current);
    messenger.showSnackBar(const SnackBar(content: Text('AI settings saved')));
    navigator.pop();
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final settings = _current.copyWith(enabled: true);
    String result;
    var ok = false;
    if (!settings.ready) {
      result = _provider.needsKey ? 'Fill in the address, the model and the API key.' : 'Fill in the address and the model.';
    } else {
      try {
        await AiClient(settings).test();
        result = 'Connected to ${Uri.tryParse(settings.baseUrl)?.host ?? 'the server'}.';
        ok = true;
      } on AiException catch (e) {
        result = e.message;
      }
    }
    if (mounted) {
      setState(() {
        _testing = false;
        _testResult = result;
        _testOk = ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(aiSettingsProvider).value;
    if (!_loaded && saved != null) _fill(saved);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI assistant'),
        actions: [TextButton(onPressed: _loaded ? _save : null, child: const Text('Save'))],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTheme.spacePulse3),
              children: [
                Card(
                  child: SwitchListTile(
                    title: const Text('Use an AI model'),
                    subtitle: const Text('Optional. Everything else works without it.'),
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                ),
                const SizedBox(height: AppTheme.spacePulse2),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacePulse3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Provider', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppTheme.spacePulse2),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final p in AiProvider.values)
                              ChoiceChip(
                                label: Text(p.label),
                                selected: _provider == p,
                                onSelected: (_) => setState(() {
                                  // A new provider starts from its own address.
                                  if (_baseUrl.text.trim().isEmpty || _baseUrl.text == _provider.baseUrl) _baseUrl.text = p.baseUrl;
                                  _provider = p;
                                  _testResult = null;
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacePulse3),
                        TextField(
                          controller: _baseUrl,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: 'Address (base URL)',
                            helperText: _provider.needsKey
                                ? 'OpenAI-compatible endpoint'
                                : 'Your server, e.g. http://my-pc.your-tailnet.ts.net:11434/v1',
                            helperMaxLines: 2,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacePulse3),
                        TextField(
                          controller: _model,
                          autocorrect: false,
                          decoration: InputDecoration(labelText: 'Model', hintText: _provider.modelHint),
                        ),
                        const SizedBox(height: AppTheme.spacePulse3),
                        TextField(
                          controller: _key,
                          obscureText: !_showKey,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: _provider.needsKey ? 'API key' : 'API key (if your server needs one)',
                            helperText: 'Stays on this phone. Never exported or backed up.',
                            suffixIcon: IconButton(
                              tooltip: _showKey ? 'Hide key' : 'Show key',
                              icon: Icon(_showKey ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () => setState(() => _showKey = !_showKey),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacePulse3),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _testing ? null : _test,
                            icon: _testing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.wifi_tethering, size: 18),
                            label: const Text('Test connection'),
                          ),
                        ),
                        if (_testResult case final result?)
                          Padding(
                            padding: const EdgeInsets.only(top: AppTheme.spacePulse2),
                            child: Text(result, style: theme.textTheme.bodyMedium?.copyWith(color: _testOk ? Colors.green.shade700 : theme.colorScheme.error)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacePulse2),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacePulse3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Look up published calories', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'The AI always checks USDA and Open Food Facts. With web search it can also find the official figure '
                          'for restaurant, chain and packaged food. Your phone does the searching.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppTheme.spacePulse2),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final p in SearchProvider.values)
                              ChoiceChip(
                                label: Text(p.label),
                                selected: _search == p,
                                onSelected: (_) => setState(() {
                                  if (_searchUrl.text.trim().isEmpty || _searchUrl.text == _search.baseUrl) _searchUrl.text = p.baseUrl;
                                  _search = p;
                                }),
                              ),
                          ],
                        ),
                        if (_search != SearchProvider.none) ...[
                          const SizedBox(height: AppTheme.spacePulse3),
                          TextField(
                            controller: _searchUrl,
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: 'Search address',
                              helperText: _search == SearchProvider.searxng
                                  ? 'Your server, e.g. http://my-pc.your-tailnet.ts.net:8080 (JSON output on)'
                                  : null,
                              helperMaxLines: 2,
                            ),
                          ),
                          if (_search.needsKey) ...[
                            const SizedBox(height: AppTheme.spacePulse3),
                            TextField(
                              controller: _searchKey,
                              obscureText: !_showSearchKey,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: InputDecoration(
                                labelText: 'Search API key',
                                helperText: 'From api-dashboard.search.brave.com. Stays on this phone.',
                                helperMaxLines: 2,
                                suffixIcon: IconButton(
                                  tooltip: _showSearchKey ? 'Hide key' : 'Show key',
                                  icon: Icon(_showSearchKey ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                  onPressed: () => setState(() => _showSearchKey = !_showSearchKey),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacePulse2),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacePulse3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('What gets sent', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppTheme.spacePulse2),
                        const Text('Only what a feature needs, and only when you tap it. "Estimate with AI" on a meal sends just the food\'s name, '
                            'which may also be searched for in the food databases and your web search. Your journal, moods and health data are never sent.'),
                        const SizedBox(height: AppTheme.spacePulse2),
                        Text(
                          'A cloud provider\'s own terms apply to what you send it. To keep everything at home, run a model on your own computer '
                          'and reach it over a private network such as Tailscale (see the guide on the DailyRhythm website).',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
