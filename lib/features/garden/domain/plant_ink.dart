import 'dart:math' as math;

/// Plant styles: the soft flat drawings, or the same plants in ink line
/// and wash, like a sketchbook.
enum PlantStyle {
  soft('Soft'),
  ink('Ink & wash');

  const PlantStyle(this.label);

  final String label;

  static PlantStyle byName(String? name) => values.firstWhere((s) => s.name == name, orElse: () => soft);
}

/// Turns a flat plant or pot SVG into ink and wash, as on the design
/// canvas: pale washes with dark outlines in register, every edge wobbling
/// like a pen line. The canvas wobbles with an SVG filter, which the app's
/// renderer doesn't support, so the points themselves are nudged instead
/// (the same way each time, so a plant doesn't shimmer).
class PlantInk {
  PlantInk._();

  static const ink = '#2B3A30';
  static const lineWidth = 2.2;

  /// How far, in the 200 × 240 drawing, a point may wander.
  static const wobble = 0.9;

  static final _svg = RegExp(r'^(<svg[^>]*>)(.*)(</svg>)$', dotAll: true);
  static final _fill = RegExp(r'fill="(#[0-9A-Fa-f]{6})"');
  static final _stroke = RegExp(r'stroke="(#[0-9A-Fa-f]{6})"');
  static final _strokeWidth = RegExp(r'stroke-width="([\d.]+)"');
  static final _shape = RegExp(r'<(path|ellipse|circle|rect)\b([^>]*?)/>');
  static final _token = RegExp(r'[A-Za-z]|-?\d*\.?\d+');

  static String inked(String svg) {
    final m = _svg.firstMatch(svg);
    if (m == null) return svg;
    var seed = 0;
    final body = m.group(2)!.replaceAllMapped(_shape, (s) => _ink(s.group(1)!, s.group(2)!, seed++));
    return '${m.group(1)}$body${m.group(3)}';
  }

  static String? _attr(String attrs, String name) => RegExp('\\b$name="([^"]*)"').firstMatch(attrs)?.group(1);
  static double _num(String attrs, String name) => double.tryParse(_attr(attrs, name) ?? '') ?? 0;

  /// One shape, inked: its outline wobbled, filled with a wash and drawn
  /// round in ink.
  static String _ink(String tag, String attrs, int seed) {
    // The ground shadow stays a soft shadow.
    if (attrs.contains('opacity="0.08"')) return '<$tag$attrs/>';
    final fill = _fill.firstMatch(attrs)?.group(1);
    final stroke = _stroke.firstMatch(attrs)?.group(1);
    final width = double.tryParse(_strokeWidth.firstMatch(attrs)?.group(1) ?? '') ?? 0;

    // The shape as a path, so its points can wobble.
    final d = switch (tag) {
      'path' => _attr(attrs, 'd') ?? '',
      'ellipse' || 'circle' => _ellipse(_num(attrs, 'cx'), _num(attrs, 'cy'), _num(attrs, tag == 'circle' ? 'r' : 'rx'), _num(attrs, tag == 'circle' ? 'r' : 'ry')),
      _ => _rect(_num(attrs, 'x'), _num(attrs, 'y'), _num(attrs, 'width'), _num(attrs, 'height'), _num(attrs, 'rx')),
    };
    final size = switch (tag) {
      'path' => 99.0,
      'rect' => math.min(_num(attrs, 'width'), _num(attrs, 'height')),
      _ => math.min(_num(attrs, tag == 'circle' ? 'r' : 'rx'), _num(attrs, tag == 'circle' ? 'r' : 'ry')),
    };
    final kept = [
      for (final a in ['transform', 'opacity', 'stroke-linecap', 'stroke-linejoin'])
        if (_attr(attrs, a) case final v?) '$a="$v"',
    ].join(' ');
    final wobbled = _wobbled(d, seed, turned: attrs.contains('rotate('));
    final path = '<path d="$wobbled" $kept';

    if (fill == null || fill == 'none') {
      // A line in the drawing (a stem, a vein, cactus spines): an ink line.
      if (stroke == null) return '<$tag$attrs/>';
      if (width >= 8) {
        // A thick stroke is a body (a cactus arm): ink a little wider
        // underneath, the wash on top, so it reads as an outlined tube.
        String tube(String colour, double w) => '<path d="$wobbled" $kept fill="none" stroke="$colour" stroke-width="${w.toStringAsFixed(1)}" stroke-linecap="round" stroke-linejoin="round"/>';
        return tube(ink, width + lineWidth * 2) + tube(_pale(stroke), width);
      }
      final pen = width >= 3 ? (width * 0.55).clamp(2.2, 3.2) : 1.3;
      return '$path fill="none" stroke="$ink" stroke-width="${pen.toStringAsFixed(1)}" stroke-linecap="round" stroke-linejoin="round"/>';
    }
    // Soil is a dark ink patch; tiny leaflets and seeds are wash only.
    if (fill.toUpperCase() == '#7A513D') return '$path fill="$ink" opacity="0.85"/>';
    final outlined = size >= 4;
    return '$path fill="${_pale(fill)}"${outlined ? ' stroke="$ink" stroke-width="$lineWidth" stroke-linejoin="round" stroke-linecap="round"' : ''}/>';
  }

  /// The outline bent by a smooth field, like the canvas's displacement
  /// filter: nearby points move together, so edges wave instead of
  /// kinking. Straight lines and long curves are split first, so they wave
  /// along their length too. A shape that is turned (a petal) gets its own
  /// field, so the copies don't wave alike.
  static String _wobbled(String d, int seed, {required bool turned}) {
    final phase = turned ? seed * 1.7 : 0.0;
    String pt(double x, double y) {
      final dx = wobble * (0.6 * math.sin(0.22 * x + 0.12 * y + phase) + 0.4 * math.sin(-0.16 * x + 0.29 * y + 2 * phase + 1));
      final dy = wobble * (0.6 * math.sin(0.19 * x - 0.23 * y + phase + 2) + 0.4 * math.sin(0.13 * x + 0.26 * y + 3 * phase + 4));
      return '${(x + dx).toStringAsFixed(2)} ${(y + dy).toStringAsFixed(2)}';
    }

    final out = StringBuffer();
    final tokens = _token.allMatches(d).map((m) => m.group(0)!).toList();
    var i = 0;
    var cmd = 'M';
    var (cx, cy) = (0.0, 0.0);
    var (sx, sy) = (0.0, 0.0);
    double next() => double.parse(tokens[i++]);

    void line(double x, double y) {
      final steps = math.max(1, (math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2)) / 8).ceil());
      for (var k = 1; k <= steps; k++) {
        out.write('L${pt(cx + (x - cx) * k / steps, cy + (y - cy) * k / steps)} ');
      }
      (cx, cy) = (x, y);
    }

    void curve(double x1, double y1, double x2, double y2, double x, double y) {
      if (math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2)) > 16) {
        // Split in half (de Casteljau).
        final (ax, ay) = ((cx + x1) / 2, (cy + y1) / 2);
        final (bx, by) = ((x1 + x2) / 2, (y1 + y2) / 2);
        final (ex, ey) = ((x2 + x) / 2, (y2 + y) / 2);
        final (fx, fy) = ((ax + bx) / 2, (ay + by) / 2);
        final (gx, gy) = ((bx + ex) / 2, (by + ey) / 2);
        final (mx, my) = ((fx + gx) / 2, (fy + gy) / 2);
        curve(ax, ay, fx, fy, mx, my);
        curve(gx, gy, ex, ey, x, y);
        return;
      }
      out.write('C${pt(x1, y1)} ${pt(x2, y2)} ${pt(x, y)} ');
      (cx, cy) = (x, y);
    }

    while (i < tokens.length) {
      if (RegExp('[A-Za-z]').hasMatch(tokens[i])) cmd = tokens[i++];
      final rel = cmd == cmd.toLowerCase();
      final (ox, oy) = rel ? (cx, cy) : (0.0, 0.0);
      switch (cmd.toUpperCase()) {
        case 'M':
          (cx, cy) = (ox + next(), oy + next());
          (sx, sy) = (cx, cy);
          out.write('M${pt(cx, cy)} ');
          // Further pairs after a move are lines.
          cmd = rel ? 'l' : 'L';
        case 'L':
          line(ox + next(), oy + next());
        case 'H':
          line((rel ? cx : 0) + next(), cy);
        case 'V':
          line(cx, (rel ? cy : 0) + next());
        case 'C':
          curve(ox + next(), oy + next(), ox + next(), oy + next(), ox + next(), oy + next());
        case 'Q':
          final (qx, qy, x, y) = (ox + next(), oy + next(), ox + next(), oy + next());
          curve(cx + (qx - cx) * 2 / 3, cy + (qy - cy) * 2 / 3, x + (qx - x) * 2 / 3, y + (qy - y) * 2 / 3, x, y);
        case 'Z':
          out.write('Z ');
          (cx, cy) = (sx, sy);
        default:
          // Arcs and the like: the drawings use none, so leave the path be.
          return d;
      }
    }
    return out.toString().trim();
  }

  /// An ellipse as four curves.
  static String _ellipse(double cx, double cy, double rx, double ry) {
    const k = 0.5523;
    String p(double x, double y) => '${x.toStringAsFixed(1)} ${y.toStringAsFixed(1)}';
    return 'M${p(cx + rx, cy)} '
        'C${p(cx + rx, cy + ry * k)} ${p(cx + rx * k, cy + ry)} ${p(cx, cy + ry)} '
        'C${p(cx - rx * k, cy + ry)} ${p(cx - rx, cy + ry * k)} ${p(cx - rx, cy)} '
        'C${p(cx - rx, cy - ry * k)} ${p(cx - rx * k, cy - ry)} ${p(cx, cy - ry)} '
        'C${p(cx + rx * k, cy - ry)} ${p(cx + rx, cy - ry * k)} ${p(cx + rx, cy)} Z';
  }

  /// A rounded rectangle as a path.
  static String _rect(double x, double y, double w, double h, double r) {
    final c = math.min(r, math.min(w, h) / 2);
    String p(double a, double b) => '${a.toStringAsFixed(1)} ${b.toStringAsFixed(1)}';
    return 'M${p(x + c, y)} L${p(x + w - c, y)} Q${p(x + w, y)} ${p(x + w, y + c)} '
        'L${p(x + w, y + h - c)} Q${p(x + w, y + h)} ${p(x + w - c, y + h)} '
        'L${p(x + c, y + h)} Q${p(x, y + h)} ${p(x, y + h - c)} '
        'L${p(x, y + c)} Q${p(x, y)} ${p(x + c, y)} Z';
  }

  /// A colour washed out to about a third of its strength, as on the canvas.
  static String _pale(String hex) {
    final v = int.parse(hex.substring(1), radix: 16);
    String mix(int c) => (c * 0.38 + 255 * 0.62).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${mix(v >> 16 & 0xFF)}${mix(v >> 8 & 0xFF)}${mix(v & 0xFF)}';
  }
}
