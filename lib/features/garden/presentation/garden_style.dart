import 'package:material_ui/material_ui.dart';

/// Colours and type for the garden screens: warm pastels on a soft green
/// ground, rounded Nunito. A dark set keeps the same feel at night.
class GardenColors {
  const GardenColors._({
    required this.ground,
    required this.bed,
    required this.hill,
    required this.card,
    required this.ink,
    required this.muted,
    required this.leaf,
    required this.accent,
    required this.onAccent,
    required this.sun,
    required this.onSun,
    required this.bloom,
    required this.onBloom,
  });

  /// Page background.
  final Color ground;

  /// The panel the plant sits in.
  final Color bed;
  final Color hill;
  final Color card;
  final Color ink;
  final Color muted;

  /// Text on [bed].
  final Color leaf;
  final Color accent;
  final Color onAccent;
  final Color sun;
  final Color onSun;
  final Color bloom;
  final Color onBloom;

  static const light = GardenColors._(
    ground: Color(0xFFEAF6EE),
    bed: Color(0xFFD3EDDD),
    hill: Color(0xFFB9DEC7),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF1E3328),
    muted: Color(0xFF4D6B5B),
    leaf: Color(0xFF2F5A43),
    accent: Color(0xFF1F6B45),
    onAccent: Color(0xFFFFFFFF),
    sun: Color(0xFFFFE9A8),
    onSun: Color(0xFF5A4300),
    bloom: Color(0xFFFFDDE7),
    onBloom: Color(0xFF7A1F3F),
  );

  static const dark = GardenColors._(
    ground: Color(0xFF13201A),
    bed: Color(0xFF1D3328),
    hill: Color(0xFF284536),
    card: Color(0xFF1A2A21),
    ink: Color(0xFFE4F1E9),
    muted: Color(0xFFA6C2B2),
    leaf: Color(0xFFBFDCCB),
    accent: Color(0xFF7FD1A3),
    onAccent: Color(0xFF0E2A1B),
    sun: Color(0xFF4A3D12),
    onSun: Color(0xFFFFE9A8),
    bloom: Color(0xFF4A2231),
    onBloom: Color(0xFFFFD3E0),
  );

  static GardenColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Nunito at [weight]. The font is variable, so the weight is also set as a
/// font variation, which every platform honours.
TextStyle nunito(double size, FontWeight weight, Color color) => TextStyle(
      fontFamily: 'Nunito',
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      color: color,
      height: 1.25,
    );

/// A titled garden card.
class GardenSection extends StatelessWidget {
  const GardenSection({super.key, required this.title, required this.colors, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final GardenColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(title, style: nunito(18, FontWeight.w900, colors.ink))),
          if (subtitle != null) Text(subtitle!, style: nunito(13, FontWeight.w600, colors.muted)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
