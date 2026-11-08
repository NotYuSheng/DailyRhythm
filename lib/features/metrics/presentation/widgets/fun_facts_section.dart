import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../garden/presentation/garden_style.dart';
import '../../data/models/metric_data.dart';
import '../../data/providers/metrics_providers.dart';
import '../../data/services/fun_facts_service.dart';

/// Light-hearted facts about the selected period, as a grid of cards.
class FunFactsSection extends ConsumerWidget {
  const FunFactsSection({super.key, required this.range});

  final DateRange range;

  static const _icons = {
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

  /// Soft card colours from the garden palette (light, dark).
  static const _tints = {
    FactKind.food: (Color(0xFFFBE0D3), Color(0xFF4A2C1E)),
    FactKind.newFood: (Color(0xFFFFE9A8), Color(0xFF4A3D12)),
    FactKind.spend: (Color(0xFFFFDDE7), Color(0xFF4A2231)),
    FactKind.events: (Color(0xFFFFE9A8), Color(0xFF4A3D12)),
    FactKind.exercise: (Color(0xFFD3EDDD), Color(0xFF1D3328)),
    FactKind.distance: (Color(0xFFDDEBFF), Color(0xFF1C2B44)),
    FactKind.sleep: (Color(0xFFE6E0FA), Color(0xFF2C2645)),
    FactKind.logging: (Color(0xFFD3EDDD), Color(0xFF1D3328)),
    FactKind.weekday: (Color(0xFFFBE0D3), Color(0xFF4A2C1E)),
    FactKind.garden: (Color(0xFFD3EDDD), Color(0xFF1D3328)),
    FactKind.memory: (Color(0xFFFFDDE7), Color(0xFF4A2231)),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final facts = ref.watch(funFactsProvider(range));

    return facts.when(
      loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
      error: (_, _) => Text('Fun facts aren’t available right now.', style: nunito(14, FontWeight.w600, colors.muted)),
      data: (list) {
        if (list.isEmpty) {
          return Text('Fun facts appear once there’s a few days of logging.', style: nunito(14, FontWeight.w600, colors.muted));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text('Fun facts', style: nunito(20, FontWeight.w900, colors.ink))),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, box) {
                // Two columns on phones, three on wider screens.
                final columns = box.maxWidth >= 600 ? 3 : 2;
                const gap = 10.0;
                final width = (box.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final fact in list)
                      SizedBox(
                        // Memories read better across the full width.
                        width: fact.kind == FactKind.memory ? box.maxWidth : width,
                        child: _FactCard(
                          fact: fact,
                          icon: _icons[fact.kind]!,
                          tint: dark ? _tints[fact.kind]!.$2 : _tints[fact.kind]!.$1,
                          colors: colors,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _FactCard extends StatelessWidget {
  const _FactCard({required this.fact, required this.icon, required this.tint, required this.colors});

  final FunFact fact;
  final IconData icon;
  final Color tint;
  final GardenColors colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colors.leaf),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(fact.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: nunito(13, FontWeight.w800, colors.leaf)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(fact.value, maxLines: 2, overflow: TextOverflow.ellipsis, style: nunito(20, FontWeight.w900, colors.ink)),
            const SizedBox(height: 2),
            Text(fact.detail, maxLines: 3, overflow: TextOverflow.ellipsis, style: nunito(13, FontWeight.w600, colors.leaf)),
          ],
        ),
      ),
    );
  }
}
