import 'package:material_ui/material_ui.dart';

import '../garden_style.dart';

/// A rounded garden pill that can be selected.
class GardenChip extends StatelessWidget {
  const GardenChip({
    super.key,
    required this.label,
    required this.selected,
    required this.colors,
    required this.onPressed,
    this.compact = false,
    this.idle,
  });

  final String label;
  final bool selected;
  final GardenColors colors;
  final VoidCallback onPressed;

  /// Less side padding, for a row of equal-width pills.
  final bool compact;

  /// Background when not selected; the card colour by default, so pass the
  /// ground colour for a pill sitting on a card.
  final Color? idle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 14),
          shape: const StadiumBorder(),
          backgroundColor: selected ? colors.accent : idle ?? colors.card,
          foregroundColor: selected ? colors.onAccent : colors.leaf,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: nunito(13, FontWeight.w800, selected ? colors.onAccent : colors.leaf),
        ),
      ),
    );
  }
}
