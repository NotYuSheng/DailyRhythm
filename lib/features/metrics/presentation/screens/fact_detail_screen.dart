import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../garden/presentation/garden_style.dart';
import '../../../garden/presentation/screens/garden_today_screen.dart';
import '../../data/services/fun_facts_service.dart';

/// How a fact's list is ordered.
enum FactSort {
  mostTimes('Most times'),
  biggest('Biggest'),
  smallest('Smallest'),
  newest('Newest'),
  oldest('Oldest'),
  name('A–Z');

  const FactSort(this.label);

  final String label;
}

/// Everything behind a fun fact, as a list that can be sorted. Rows that
/// are one day open that day.
class FactDetailScreen extends StatefulWidget {
  const FactDetailScreen({super.key, required this.detail});

  final FactDetail detail;

  @override
  State<FactDetailScreen> createState() => _FactDetailScreenState();
}

class _FactDetailScreenState extends State<FactDetailScreen> {
  late final _rows = widget.detail.rows;

  /// Only the orders the rows can be put in.
  late final _sorts = [
    if (_rows.any((r) => r.count != null)) FactSort.mostTimes,
    if (_rows.any((r) => r.value != null)) ...[FactSort.biggest, if (widget.detail.valueSort == null) FactSort.smallest],
    if (_rows.any((r) => r.date != null)) ...[FactSort.newest, FactSort.oldest],
    FactSort.name,
  ];
  late FactSort _sort = widget.detail.byDate && _sorts.contains(FactSort.newest) ? FactSort.newest : _sorts.first;

  int _compare(FactRow a, FactRow b) => switch (_sort) {
        FactSort.mostTimes => (b.count ?? 0) != (a.count ?? 0) ? (b.count ?? 0).compareTo(a.count ?? 0) : (b.value ?? 0).compareTo(a.value ?? 0),
        FactSort.biggest => (b.value ?? 0).compareTo(a.value ?? 0),
        FactSort.smallest => (a.value ?? 0).compareTo(b.value ?? 0),
        FactSort.newest => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)),
        FactSort.oldest => (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)),
        FactSort.name => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      };

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    // Groups keep the order the rows came in; rows sort within each.
    final groups = <String?, List<FactRow>>{};
    for (final r in _rows) {
      groups.putIfAbsent(r.group, () => []).add(r);
    }
    for (final list in groups.values) {
      list.sort(_compare);
    }

    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(title: Text(widget.detail.title), backgroundColor: colors.ground),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (widget.detail.note case final note?)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(note, style: nunito(14, FontWeight.w600, colors.muted)),
            ),
          if (_rows.length > 1 && _sorts.length > 1)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _sorts)
                  ChoiceChip(
                    label: Text(s == FactSort.biggest ? widget.detail.valueSort ?? s.label : s.label),
                    selected: _sort == s,
                    onSelected: (_) => setState(() => _sort = s),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Text('${_rows.length} ${_rows.length == 1 ? 'item' : 'items'}', style: nunito(13, FontWeight.w700, colors.muted)),
          for (final MapEntry(key: group, value: rows) in groups.entries) ...[
            if (group != null)
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 4),
                child: Semantics(header: true, child: Text(group, style: nunito(16, FontWeight.w900, colors.ink))),
              ),
            Card(
              margin: const EdgeInsets.only(top: 6),
              color: colors.card,
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  for (final (i, r) in rows.indexed) ...[
                    if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: colors.ground),
                    _Row(row: r, colors: colors),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.colors});

  final FactRow row;
  final GardenColors colors;

  static final _date = DateFormat('d MMM y');

  @override
  Widget build(BuildContext context) {
    final date = row.date;
    // A label that is itself a date doesn't need the date again.
    final sub = [?row.sub, if (date != null && !row.label.contains(DateFormat('y').format(date))) _date.format(date)].join(' · ');
    return ListTile(
      minTileHeight: 52,
      title: Text(row.label, style: nunito(15, FontWeight.w800, colors.ink)),
      subtitle: sub.isEmpty ? null : Text(sub, style: nunito(13, FontWeight.w600, colors.muted)),
      trailing: row.valueText == null ? null : Text(row.valueText!, style: nunito(15, FontWeight.w800, colors.leaf)),
      onTap: date == null
          ? null
          : () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => GardenTodayScreen(day: date))),
    );
  }
}
