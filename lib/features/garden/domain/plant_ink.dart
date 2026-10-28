/// Plant styles: the soft flat drawings, or the same shapes as ink lines
/// over pale washes, like a sketchbook.
enum PlantStyle {
  soft('Soft'),
  ink('Ink & wash');

  const PlantStyle(this.label);

  final String label;

  static PlantStyle byName(String? name) => values.firstWhere((s) => s.name == name, orElse: () => soft);
}

/// Turns a flat plant or pot SVG into ink and wash: every shape once as a
/// pale wash, nudged off its line as a brush would be, and again as a dark
/// outline on top. Built from the same drawing, so every plant has it.
class PlantInk {
  PlantInk._();

  static const ink = '#2F3A35';

  static final _svg = RegExp(r'^(<svg[^>]*>)(.*)(</svg>)$', dotAll: true);
  static final _fill = RegExp(r'fill="(#[0-9A-Fa-f]{6})"');
  static final _stroke = RegExp(r'stroke="(#[0-9A-Fa-f]{6})"');
  static final _strokeWidth = RegExp(r'stroke-width="([\d.]+)"');
  static final _shape = RegExp(r'<(path|ellipse|circle|rect)\b([^>]*?)/>');

  static String inked(String svg) {
    final m = _svg.firstMatch(svg);
    if (m == null) return svg;
    final body = m.group(2)!;
    return '${m.group(1)}'
        '<g transform="translate(3.5 2.5)" opacity="0.85">${_wash(body)}</g>'
        '<g>${_lines(body)}</g>'
        '${m.group(3)}';
  }

  /// Fills and strokes as pale washes; thin detail strokes are left to the ink.
  static String _wash(String body) => body
      .replaceAllMapped(_fill, (f) => 'fill="${_pale(f.group(1)!)}"')
      .replaceAllMapped(_stroke, (s) => 'stroke="${_pale(s.group(1)!)}"');

  /// Every shape as an outline: no fill, ink strokes, thinner where the
  /// drawing had thick stems.
  static String _lines(String body) => body.replaceAllMapped(_shape, (s) {
        var attrs = s.group(2)!;
        final stroked = _stroke.hasMatch(attrs);
        final width = double.tryParse(_strokeWidth.firstMatch(attrs)?.group(1) ?? '') ?? 0;
        // Shadows, soil and tiny leaflets (a fern's) stay wash only: lines
        // round each would be a scribble.
        if (attrs.contains('opacity="0.08"') || attrs.contains('#7A513D')) return '';
        if (s.group(1) == 'ellipse' && (double.tryParse(RegExp(r'ry="([\d.]+)"').firstMatch(attrs)?.group(1) ?? '') ?? 9) < 4) return '';
        attrs = attrs.replaceAll(_fill, 'fill="none"').replaceAll(_stroke, 'stroke="$ink"').replaceAll(RegExp(r'\sopacity="[\d.]+"'), '');
        if (stroked) {
          // A thick stem becomes a pen line along it; fine detail stays fine.
          attrs = attrs.replaceAll(_strokeWidth, 'stroke-width="${(width * 0.45).clamp(1.2, 2.6).toStringAsFixed(1)}"');
        } else {
          if (!attrs.contains('fill=')) attrs += ' fill="none"';
          attrs += ' stroke="$ink" stroke-width="1.8" stroke-linejoin="round" stroke-linecap="round"';
        }
        return '<${s.group(1)}$attrs/>';
      });

  /// A colour mixed halfway to paper white.
  static String _pale(String hex) {
    final v = int.parse(hex.substring(1), radix: 16);
    String mix(int c) => ((c + 255) / 2).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${mix(v >> 16 & 0xFF)}${mix(v >> 8 & 0xFF)}${mix(v & 0xFF)}';
  }
}
