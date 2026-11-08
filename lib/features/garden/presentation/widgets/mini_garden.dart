import 'package:material_ui/material_ui.dart';

import '../../domain/garden_day.dart';
import '../../domain/plant.dart';
import 'plant_view.dart';

/// A month's plants, small, in calendar order (Monday first).
class MiniGarden extends StatelessWidget {
  const MiniGarden({super.key, required this.month, required this.days});

  final DateTime month;
  final List<GardenDay> days;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) {
          final cell = box.maxWidth / 7;
          final lead = DateTime(month.year, month.month).weekday - 1;
          return Wrap(
            children: [
              for (var i = 0; i < lead; i++) SizedBox(width: cell, height: 1),
              for (final d in days)
                SizedBox(
                  width: cell,
                  child: PlantView(spec: d.plant, width: cell, potColor: potColors[d.date.day % potColors.length]),
                ),
            ],
          );
        },
      ),
    );
  }
}
