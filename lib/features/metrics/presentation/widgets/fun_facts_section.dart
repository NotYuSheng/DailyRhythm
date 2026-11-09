import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../garden/presentation/garden_style.dart';
import '../../data/models/metric_data.dart';
import '../../data/providers/metrics_providers.dart';
import '../../data/services/fun_facts_service.dart';
import '../screens/fact_detail_screen.dart';

/// Light-hearted facts about the selected period: the most telling ones as
/// big cards to swipe through, the rest as a list. Each opens what's
/// behind it.
class FunFactsSection extends ConsumerWidget {
  const FunFactsSection({super.key, required this.range});

  final DateRange range;

  /// Facts shown big, in this order: habits and favourites before records.
  static const highlights = [FactKind.weekday, FactKind.food, FactKind.exercise, FactKind.garden, FactKind.distance, FactKind.memory];

  static const icons = {
    FactKind.food: Icons.ramen_dining_outlined,
    FactKind.newFood: Icons.explore_outlined,
    FactKind.spend: Icons.payments_outlined,
    FactKind.events: Icons.celebration_outlined,
    FactKind.exercise: Icons.fitness_center_outlined,
    FactKind.distance: Icons.directions_walk,
    FactKind.sleep: Icons.bedtime_outlined,
    FactKind.logging: Icons.event_available_outlined,
    FactKind.weekday: Icons.calendar_view_week_outlined,
    FactKind.garden: Icons.local_florist_outlined,
    FactKind.memory: Icons.history_edu_outlined,
  };

  /// Colour by topic: food amber, money pink, body green, rest indigo,
  /// logging teal.
  static const tones = {
    FactKind.food: DayTone.food,
    FactKind.newFood: DayTone.food,
    FactKind.weekday: DayTone.food,
    FactKind.spend: DayTone.gift,
    FactKind.events: DayTone.gift,
    FactKind.memory: DayTone.gift,
    FactKind.exercise: DayTone.move,
    FactKind.distance: DayTone.move,
    FactKind.garden: DayTone.move,
    FactKind.sleep: DayTone.sleep,
    FactKind.logging: DayTone.tag,
  };

  static Future<void> open(BuildContext context, FunFact fact) async {
    final detail = await fact.details!();
    if (!context.mounted) return;
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => FactDetailScreen(detail: detail)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);
    final facts = ref.watch(funFactsProvider(range));

    return facts.when(
      loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
      error: (_, _) => Text('Fun facts aren’t available right now.', style: nunito(14, FontWeight.w600, colors.muted)),
      data: (list) {
        if (list.isEmpty) {
          return Text('Fun facts appear once there’s a few days of logging.', style: nunito(14, FontWeight.w600, colors.muted));
        }
        final big = [for (final k in highlights) ...list.where((f) => f.kind == k)];
        final rest = [for (final f in list) if (!big.contains(f)) f];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text('Fun facts', style: nunito(20, FontWeight.w900, colors.ink))),
            const SizedBox(height: 10),
            if (big.isNotEmpty) _Highlights(facts: big, colors: colors),
            if (rest.isNotEmpty) ...[
              const SizedBox(height: 12),
              Material(
                color: colors.card,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final (i, f) in rest.indexed) ...[
                      if (i > 0) Divider(height: 1, indent: 62, endIndent: 14, color: colors.ground),
                      _FactRow(fact: f, colors: colors),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The period's most telling facts as big cards to swipe through.
class _Highlights extends StatefulWidget {
  const _Highlights({required this.facts, required this.colors});

  final List<FunFact> facts;
  final GardenColors colors;

  @override
  State<_Highlights> createState() => _HighlightsState();
}

class _HighlightsState extends State<_Highlights> {
  final _pages = PageController(viewportFraction: 0.92);
  var _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final facts = widget.facts;
    // Taller with large text, so the words fit.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Column(
      children: [
        SizedBox(
          height: 184 * scale.clamp(1.0, 1.8),
          child: PageView.builder(
            controller: _pages,
            padEnds: false,
            itemCount: facts.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.only(right: i == facts.length - 1 ? 0 : 10),
              child: _BigFact(fact: facts[i], colors: colors, label: '${i + 1} of ${facts.length}'),
            ),
          ),
        ),
        if (facts.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < facts.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(color: i == _page ? colors.accent : colors.hill, borderRadius: BorderRadius.circular(4)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BigFact extends StatelessWidget {
  const _BigFact({required this.fact, required this.colors, required this.label});

  final FunFact fact;
  final GardenColors colors;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tone = FunFactsSection.tones[fact.kind]!;
    final card = Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FunFactsSection.icons[fact.kind], size: 20, color: tone.ink(context)),
              const SizedBox(width: 8),
              Expanded(child: Text(fact.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: nunito(14, FontWeight.w800, tone.ink(context)))),
              Text(label, style: nunito(12, FontWeight.w800, colors.muted)),
            ],
          ),
          const Spacer(),
          Text(fact.value, maxLines: 2, overflow: TextOverflow.ellipsis, style: nunito(28, FontWeight.w900, colors.ink).copyWith(height: 1.1)),
          const SizedBox(height: 4),
          Text(fact.detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: nunito(14, FontWeight.w700, colors.muted)),
          if (fact.details != null) ...[
            const SizedBox(height: 8),
            Text('See the list ›', style: nunito(13, FontWeight.w800, colors.accent)),
          ],
        ],
      ),
    );
    return Semantics(
      container: true,
      button: fact.details != null,
      hint: fact.details != null ? 'Shows the full list' : null,
      child: Material(
        color: tone.tint(context),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: fact.details == null ? card : InkWell(onTap: () => FunFactsSection.open(context, fact), child: card),
      ),
    );
  }
}

/// A fact as one row: its icon, what it is and a line of detail, the
/// value on the right.
class _FactRow extends StatelessWidget {
  const _FactRow({required this.fact, required this.colors});

  final FunFact fact;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    final tone = FunFactsSection.tones[fact.kind]!;
    return InkWell(
      onTap: fact.details == null ? null : () => FunFactsSection.open(context, fact),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: tone.tint(context), borderRadius: BorderRadius.circular(12)),
                child: Icon(FunFactsSection.icons[fact.kind], size: 20, color: tone.ink(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fact.title, style: nunito(14, FontWeight.w800, colors.ink)),
                    Text(fact.detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: nunito(12, FontWeight.w700, colors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(fact.value, textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis, style: nunito(17, FontWeight.w900, colors.ink)),
              ),
              if (fact.details != null) Icon(Icons.chevron_right, size: 20, color: colors.muted) else const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }
}
