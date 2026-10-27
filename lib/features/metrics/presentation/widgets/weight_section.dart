import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/utils/date_utils.dart';
import '../../../garden/presentation/garden_style.dart';
import '../../../health/data/models/health_metric.dart';
import '../../../profile/data/profile_providers.dart';
import '../../../profile/data/weight_repository.dart';
import '../../data/models/metric_data.dart';

/// Weight over the period: the latest, the change since the first, and a
/// line between them; and a button to log today's.
class WeightSection extends ConsumerWidget {
  const WeightSection({super.key, required this.range});

  final DateRange range;

  static final _day = DateFormat('d MMM');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);
    final weights = ref.watch(weightsProvider(range)).value ?? const <HealthMetric>[];
    final latest = ref.watch(profileProvider).value?.weightKg;

    String kg(double v) => '${v.toStringAsFixed(1)} kg';
    final first = weights.isEmpty ? null : weights.first;
    final last = weights.isEmpty ? null : weights.last;
    final change = first == null || last == null || first == last ? null : last.value - first.value;

    return GardenSection(
      title: 'Weight',
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (last == null)
            Text('Log your weight now and then to see how it changes.', style: nunito(14, FontWeight.w600, colors.muted))
          else ...[
            Text('${kg(last.value)} on ${_day.format(last.date)}', style: nunito(18, FontWeight.w900, colors.ink)),
            if (change != null)
              Text(
                '${change >= 0 ? '+' : '−'}${change.abs().toStringAsFixed(1)} kg since ${_day.format(first!.date)}',
                style: nunito(13, FontWeight.w700, colors.muted),
              ),
            if (weights.length >= 2) ...[
              const SizedBox(height: 10),
              Semantics(
                label: 'Weight from ${kg(first!.value)} to ${kg(last.value)} over ${weights.length} entries',
                excludeSemantics: true,
                child: SizedBox(
                  height: 70,
                  child: CustomPaint(painter: _WeightLine(weights, range, colors.accent, colors.bed)),
                ),
              ),
            ],
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: colors.accent),
              onPressed: () => logWeight(context, ref, latest),
              icon: const Icon(Icons.monitor_weight_outlined, size: 18),
              label: const Text('Log weight'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks for today's weight and saves it.
Future<void> logWeight(BuildContext context, WidgetRef ref, double? current) async {
  final kg = await showDialog<double>(context: context, builder: (_) => _WeightDialog(current: current));
  if (kg == null) return;
  await WeightRepository().log(DateTime.now(), kg);
  ref.invalidate(weightsProvider);
  ref.invalidate(profileProvider);
}

class _WeightDialog extends StatefulWidget {
  const _WeightDialog({this.current});

  final double? current;

  @override
  State<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  late final _controller = TextEditingController(text: widget.current?.toStringAsFixed(1) ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final v = double.tryParse(_controller.text.trim());
    if (v != null && v >= 20 && v <= 400) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Today’s weight'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(suffixText: 'kg'),
          onSubmitted: (_) => _save(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      );
}

class _WeightLine extends CustomPainter {
  _WeightLine(this.weights, this.range, this.line, this.grid);

  final List<HealthMetric> weights;
  final DateRange range;
  final Color line;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final start = dayOf(weights.first.date.isBefore(range.start) ? weights.first.date : range.start);
    final span = daysBetween(start, dayOf(range.end)).clamp(1, 1 << 30).toDouble();
    final values = weights.map((w) => w.value);
    final low = values.reduce((a, b) => a < b ? a : b) - 0.5;
    final high = values.reduce((a, b) => a > b ? a : b) + 0.5;
    Offset at(HealthMetric w) => Offset(
          size.width * daysBetween(start, dayOf(w.date)) / span,
          size.height * (1 - (w.value - low) / (high - low)),
        );
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), Paint()..color = grid..strokeWidth = 1);
    final path = Path()..moveTo(at(weights.first).dx, at(weights.first).dy);
    for (final w in weights.skip(1)) {
      path.lineTo(at(w).dx, at(w).dy);
    }
    canvas.drawPath(path, Paint()..color = line..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round);
    for (final w in weights) {
      canvas.drawCircle(at(w), 3.5, Paint()..color = line);
    }
  }

  @override
  bool shouldRepaint(_WeightLine old) => old.weights != weights || old.line != line;
}
