import 'package:daily_rhythm/features/metrics/data/services/fun_facts_service.dart';
import 'package:daily_rhythm/features/metrics/presentation/screens/fact_detail_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final detail = FactDetail(
    title: 'Meals by price',
    rows: [
      FactRow(label: 'Kopi', date: DateTime(2026, 3, 1), value: 1.5, valueText: '\$1.50'),
      FactRow(label: 'Wagyu don', date: DateTime(2026, 3, 12), value: 28, valueText: '\$28.00'),
      FactRow(label: 'Laksa', date: DateTime(2026, 3, 5), value: 6, valueText: '\$6.00'),
    ],
  );

  Future<void> pump(WidgetTester tester, FactDetail d) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: FactDetailScreen(detail: d))));
    await tester.pumpAndSettle();
  }

  List<String> order(WidgetTester tester) {
    final ys = {for (final n in ['Kopi', 'Wagyu don', 'Laksa']) n: tester.getTopLeft(find.text(n)).dy};
    return ys.keys.toList()..sort((a, b) => ys[a]!.compareTo(ys[b]!));
  }

  testWidgets('opens biggest first and sorts by size, date or name', (tester) async {
    await pump(tester, detail);
    expect(order(tester), ['Wagyu don', 'Laksa', 'Kopi']);
    for (final (sort, expected) in [
      ('Smallest', ['Kopi', 'Laksa', 'Wagyu don']),
      ('Newest', ['Wagyu don', 'Laksa', 'Kopi']),
      ('Oldest', ['Kopi', 'Laksa', 'Wagyu don']),
      ('A–Z', ['Kopi', 'Laksa', 'Wagyu don']),
    ]) {
      await tester.tap(find.text(sort));
      await tester.pumpAndSettle();
      expect(order(tester), expected, reason: sort);
    }
  });

  testWidgets('a list of days opens newest first and offers only the orders that apply', (tester) async {
    await pump(tester, FactDetail(title: 'Days not logged', byDate: true, rows: [
      for (final d in [4, 7]) FactRow(label: 'March $d', date: DateTime(2026, 3, d)),
    ]));
    expect(find.text('Biggest'), findsNothing, reason: 'days have no size');
    expect(tester.getTopLeft(find.text('March 7')).dy, lessThan(tester.getTopLeft(find.text('March 4')).dy));
  });

  testWidgets('grouped rows sit under their headings', (tester) async {
    await pump(tester, const FactDetail(title: 'What each weekday is for', rows: [
      FactRow(label: 'Wing rice', group: 'Mondays', value: 1, valueText: '100%'),
      FactRow(label: 'Gym', group: 'Fridays', value: 0.5, valueText: '50%'),
    ]));
    expect(tester.getTopLeft(find.text('Mondays')).dy, lessThan(tester.getTopLeft(find.text('Wing rice')).dy));
    expect(tester.getTopLeft(find.text('Wing rice')).dy, lessThan(tester.getTopLeft(find.text('Fridays')).dy));
  });

  testWidgets('a weekday opens on most times, and can sort by share instead', (tester) async {
    await pump(tester, const FactDetail(title: 'What each weekday is for', valueSort: 'Highest share', rows: [
      FactRow(label: 'Chee cheong fun', group: 'Mondays', count: 3, value: 0.75, valueText: '75%'),
      FactRow(label: 'Chicken rice', group: 'Mondays', count: 12, value: 0.4, valueText: '40%'),
    ]));
    double top(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(top('Chicken rice'), lessThan(top('Chee cheong fun')), reason: '12 times before 3');
    expect(find.text('Smallest'), findsNothing);
    await tester.tap(find.text('Highest share'));
    await tester.pumpAndSettle();
    expect(top('Chee cheong fun'), lessThan(top('Chicken rice')));
  });
}
