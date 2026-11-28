import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/database/database_provider.dart';
import '../../../shared/utils/date_utils.dart';
import '../../ai/data/ai_providers.dart';
import '../../garden/presentation/widgets/day_log_card.dart';
import '../../meals/presentation/screens/add_meal_screen.dart';
import '../data/tidy_service.dart';
import '../domain/tidy_item.dart';

/// Looks over a range of entries for what's worth fixing: suggested fixes
/// to tick and apply, and entries worth a look.
class TidyScreen extends ConsumerStatefulWidget {
  const TidyScreen({super.key, this.start, this.end, this.askAi = false, this.title});

  /// The range to check; last month when not given.
  final DateTime? start;
  final DateTime? end;

  /// Start with the AI switched on (after an update, say).
  final bool askAi;

  final String? title;

  @override
  ConsumerState<TidyScreen> createState() => _TidyScreenState();
}

enum _Range { lastMonth, thisMonth, threeMonths, all, custom }

class _TidyScreenState extends ConsumerState<TidyScreen> {
  late DateTime _start;
  late DateTime _end;
  late _Range _range;
  late bool _askAi = widget.askAi;
  String? _progress;
  TidyReport? _report;
  final _picked = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.start != null) {
      _start = dayOf(widget.start!);
      _end = dayOf(widget.end ?? DateTime.now());
      _range = _Range.custom;
    } else {
      _setRange(_Range.lastMonth);
    }
  }

  void _setRange(_Range range) {
    final today = dayOf(DateTime.now());
    _range = range;
    final (start, end) = switch (range) {
      _Range.lastMonth => (DateTime(today.year, today.month - 1), DateTime(today.year, today.month, 0)),
      _Range.thisMonth => (DateTime(today.year, today.month), today),
      _Range.threeMonths => (DateTime(today.year, today.month - 3, today.day), today),
      _Range.all => (DateTime(2000), today),
      _Range.custom => (_start, _end),
    };
    _start = start;
    _end = end;
  }

  TidyService get _service => TidyService(ref.read(databaseProvider));

  Future<void> _check() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _progress = 'Looking…';
      _report = null;
    });
    try {
      final found = await _service.check(_start, _end);
      var fixes = found.fixes;
      final ai = _askAi ? ref.read(aiClientProvider) : null;
      if (ai != null) {
        final more = await _service.askAi(ai, _start, _end, progress: (done, total) {
          if (mounted) setState(() => _progress = 'Asking your AI: $done of $total foods…');
        });
        fixes = _merge(fixes, more);
      }
      _show(TidyReport(fixes: fixes, flags: found.flags));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Stopped: $e')));
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  static List<TidyFix> _merge(List<TidyFix> a, List<TidyFix> b) {
    final keys = {for (final f in a) f.key};
    return [...a, for (final f in b) if (keys.add(f.key)) f];
  }

  void _show(TidyReport report) {
    if (!mounted) return;
    setState(() {
      _report = report;
      _picked
        ..clear()
        ..addAll(report.fixes.map((f) => f.key));
    });
  }

  Future<void> _loadFile() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.platform.pickFiles(dialogTitle: 'Choose a suggestions file', type: FileType.custom, allowedExtensions: ['json'], withData: true);
    final file = picked?.files.singleOrNull;
    if (file == null) return;
    try {
      final text = utf8.decode(file.bytes ?? await File(file.path!).readAsBytes());
      final fixes = await _service.load(text);
      _show(TidyReport(fixes: _merge(_report?.fixes ?? const [], fixes), flags: _report?.flags ?? const []));
      messenger.showSnackBar(SnackBar(content: Text('${fixes.length} suggestions to look over')));
    } on FormatException {
      messenger.showSnackBar(const SnackBar(content: Text('That isn’t a suggestions file.')));
    }
  }

  Future<void> _apply() async {
    final report = _report;
    if (report == null) return;
    final fixes = [for (final f in report.fixes) if (_picked.contains(f.key)) f];
    final left = [for (final f in report.fixes) if (!_picked.contains(f.key)) f];
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _progress = 'Applying…');
    try {
      final applied = await _service.apply(fixes, progress: (done, total) {
        if (mounted) setState(() => _progress = 'Applying $done of $total…');
      });
      if (mounted) invalidateDayLog(ref, DateTime.now());
      _show(TidyReport(fixes: left, flags: report.flags));
      messenger.showSnackBar(SnackBar(content: Text('Tidied $applied ${applied == 1 ? 'entry' : 'entries'}')));
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Future<void> _dismiss(String key) async {
    await _service.dismiss([key]);
    final r = _report;
    if (r == null || !mounted) return;
    setState(() {
      _picked.remove(key);
      _report = TidyReport(fixes: [for (final f in r.fixes) if (f.key != key) f], flags: [for (final f in r.flags) if (f.key != key) f]);
    });
  }

  Future<void> _open(TidyFlag flag) async {
    final db = ref.read(databaseProvider);
    final entry = await db.getMealEntry(flag.mealId);
    if (entry == null || !mounted) return;
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => AddMealScreen(entry: entry)));
    if (mounted) invalidateDayLog(ref, entry.date);
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: dayOf(DateTime.now()),
      initialDateRange: DateTimeRange(start: _start.isBefore(DateTime(2000, 1, 2)) ? DateTime(dayOf(DateTime.now()).year) : _start, end: _end),
    );
    if (picked == null) return;
    setState(() {
      _range = _Range.custom;
      _start = picked.start;
      _end = picked.end;
      _report = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ai = ref.watch(aiClientProvider);
    final report = _report;
    final busy = _progress != null;
    final date = DateFormat.yMMMd();
    final rows = <Widget>[
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacePulse3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Entries from', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppTheme.spacePulse2),
              Wrap(
                spacing: AppTheme.spacePulse2,
                runSpacing: AppTheme.spacePulse2,
                children: [
                  for (final (r, label) in [
                    (_Range.lastMonth, 'Last month'),
                    (_Range.thisMonth, 'This month'),
                    (_Range.threeMonths, 'Last 3 months'),
                    (_Range.all, 'All time'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _range == r,
                      onSelected: busy ? null : (_) => setState(() {
                        _setRange(r);
                        _report = null;
                      }),
                    ),
                  ChoiceChip(
                    label: Text(_range == _Range.custom ? '${date.format(_start)} – ${date.format(_end)}' : 'Pick dates…'),
                    selected: _range == _Range.custom,
                    onSelected: busy ? null : (_) => _pickRange(),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ask my AI too'),
                subtitle: Text(ai == null
                    ? 'Set up the AI assistant in Settings to find snacks, two foods in one name and brands'
                    : 'Finds snacks, two foods in one name and brands. Sends only the foods’ names'),
                value: _askAi && ai != null,
                onChanged: ai == null || busy ? null : (v) => setState(() => _askAi = v),
              ),
              Wrap(
                spacing: AppTheme.spacePulse2,
                runSpacing: AppTheme.spacePulse1,
                children: [
                  FilledButton.icon(onPressed: busy ? null : _check, icon: const Icon(Icons.search), label: const Text('Check')),
                  TextButton.icon(onPressed: busy ? null : _loadFile, icon: const Icon(Icons.file_open_outlined), label: const Text('Load suggestions')),
                ],
              ),
              if (_progress case final p?) ...[
                const SizedBox(height: AppTheme.spacePulse2),
                Row(children: [
                  const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Flexible(child: Text(p)),
                ]),
              ],
            ],
          ),
        ),
      ),
    ];
    final items = <Widget>[];
    if (report != null) {
      if (report.isEmpty) {
        items.add(Padding(padding: const EdgeInsets.all(24), child: Text('Nothing to tidy. Nice.', style: theme.textTheme.titleMedium, textAlign: TextAlign.center)));
      }
      for (final type in TidyFix.types) {
        final group = [for (final f in report.fixes) if (f.type == type) f];
        if (group.isEmpty) continue;
        final all = group.every((f) => _picked.contains(f.key));
        items.add(CheckboxListTile(
          value: all,
          onChanged: busy ? null : (on) => setState(() => on! ? _picked.addAll(group.map((f) => f.key)) : _picked.removeAll(group.map((f) => f.key))),
          title: Text('${TidyFix.titles[type]} (${group.length})', style: theme.textTheme.titleMedium),
        ));
        for (final f in group) {
          items.add(CheckboxListTile(
            dense: true,
            value: _picked.contains(f.key),
            onChanged: busy ? null : (on) => setState(() => on! ? _picked.add(f.key) : _picked.remove(f.key)),
            title: Text(f.label),
            subtitle: f.date == null ? null : Text(date.format(f.date!)),
            secondary: IconButton(icon: const Icon(Icons.close), tooltip: 'Not this one', onPressed: () => _dismiss(f.key)),
          ));
        }
      }
      if (report.flags.isNotEmpty) {
        items.add(ListTile(title: Text('Worth a look (${report.flags.length})', style: theme.textTheme.titleMedium)));
        for (final f in report.flags) {
          items.add(ListTile(
            dense: true,
            title: Text(f.name),
            subtitle: Text('${date.format(f.date)} · ${f.reason}'),
            onTap: () => _open(f),
            trailing: IconButton(icon: const Icon(Icons.close), tooltip: 'Fine as it is', onPressed: () => _dismiss(f.key)),
          ));
        }
      }
    }
    final picked = report == null ? 0 : report.fixes.where((f) => _picked.contains(f.key)).length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Tidy up')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(AppTheme.spacePulse3, AppTheme.spacePulse3, AppTheme.spacePulse3, 96),
        itemCount: rows.length + items.length,
        itemBuilder: (context, i) => i < rows.length ? rows[i] : items[i - rows.length],
      ),
      floatingActionButton: picked == 0
          ? null
          : FloatingActionButton.extended(onPressed: busy ? null : _apply, icon: const Icon(Icons.check), label: Text('Apply $picked')),
    );
  }
}
