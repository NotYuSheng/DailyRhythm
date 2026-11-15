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
/// line between them. Weight is logged on Today.
class WeightSection extends ConsumerWidget {
  const WeightSection({super.key, required this.range});

  final DateRange range;

  static final _day = DateFormat('d MMM');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);
    final weights = ref.watch(weightsProvider(range)).value ?? const <HealthMetric>[];

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
            Text('Log your weight on Today now and then to see how it changes.', style: nunito(14, FontWeight.w600, colors.muted))
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
        ],
      ),
    );
  }
}

/// Asks for the weight on [day] and saves it; [existing] is the one
/// already there, which can be changed or removed.
Future<void> logWeight(BuildContext context, WidgetRef ref, DateTime day, {HealthMetric? existing, double? suggested}) async {
  final isToday = dayOf(DateTime.now()) == dayOf(day);
  final kg = await showDialog<double>(
    context: context,
    builder: (_) => _WeightDialog(
      title: isToday ? 'Today’s weight' : 'Weight on ${DateFormat('d MMM').format(day)}',
      current: existing?.value ?? suggested,
      removable: existing?.source == HealthSource.manual,
    ),
  );
  if (kg == null) return;
  final weights = WeightRepository();
  if (kg == 0) {
    await weights.remove(day);
  } else {
    await weights.log(day, kg);
  }
  ref.invalidate(weightsProvider);
  ref.invalidate(weightOnProvider);
  ref.invalidate(profileProvider);
}

class _WeightDialog extends StatefulWidget {
  const _WeightDialog({required this.title, this.current, this.removable = false});

  final String title;
  final double? current;

  /// Offers Remove, which pops 0.
  final bool removable;

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
        title: Text(widget.title),
        content: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(suffixText: 'kg'),
          onSubmitted: (_) => _save(),
        ),
        actions: [
          if (widget.removable) TextButton(onPressed: () => Navigator.pop(context, 0.0), child: const Text('Remove')),
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
