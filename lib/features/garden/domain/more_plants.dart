import 'dart:math' as math;

/// Each kind of day's second plant in every season, in the same 200 × 240
/// box and style as the others: the stem meets the soil at (100, 176).
/// Each takes its variety's colours (0 to 2).
class MoreArt {
  MoreArt._();

  static String _f(num n) => n.toStringAsFixed(1);

  static String _stem(String d, {String colour = '#3F9E6A', num width = 5}) =>
      '<path d="$d" fill="none" stroke="$colour" stroke-width="$width" stroke-linecap="round"/>';

  static String _leaf(num x, num y, num angle, {num length = 40, String fill = '#5BB884'}) =>
      '<path d="M0 0 C${_f(length * 0.25)} -12 ${_f(length * 0.75)} -12 $length 0 C${_f(length * 0.75)} 10 ${_f(length * 0.25)} 10 0 0 Z" '
      'fill="$fill" transform="translate($x $y) rotate($angle)"/>';

  static String _petals(int n, num r, num rx, num ry, String fill, {num offset = 0}) => [
        for (var k = 0; k < n; k++)
          '<ellipse cx="0" cy="${-r}" rx="$rx" ry="$ry" fill="$fill" transform="rotate(${_f(offset + k * 360 / n)})"/>',
      ].join();

  static (double, double) _polar(num angle, num r, {num cx = 100, num cy = 170}) =>
      (cx + math.sin(angle * math.pi / 180) * r, cy - math.cos(angle * math.pi / 180) * r);

  // ---------------- Spring ----------------

  static const crocuses = ['#B7A0E8', '#FFFFFF', '#F7D33C'];
  static String crocus(int v) {
    final b = StringBuffer();
    for (final (dx, h) in const [(-22, 120), (0, 104), (22, 116)]) {
      final x = 100 + dx;
      b
        ..write('<path d="M$x 172 C${x - 6} 150 ${x - 8} ${h + 20} ${x - 4} ${h + 4}" fill="none" stroke="#5BB884" stroke-width="3" stroke-linecap="round"/>')
        ..write(_stem('M$x 172 L$x ${h + 14}', width: 4))
        ..write('<path d="M${x - 9} ${h + 14} C${x - 12} ${h - 2} ${x - 6} ${h - 14} $x ${h - 16} C${x + 6} ${h - 14} ${x + 12} ${h - 2} ${x + 9} ${h + 14} Z" '
            'fill="${crocuses[v]}" stroke="#9C8BCF" stroke-width="1.4"/>')
        ..write('<path d="M$x ${h + 12} L$x ${h - 10}" stroke="#F2A23C" stroke-width="2.4" stroke-linecap="round"/>');
    }
    return b.toString();
  }

  static const hensAndChicksTips = ['#C2507E', '#7A9E5A', '#D9902E'];
  static String hensAndChicks(int v) =>
      _rosette(100, 166, 1.0, hensAndChicksTips[v]) + _rosette(68, 170, 0.55, hensAndChicksTips[v]) + _rosette(134, 170, 0.6, hensAndChicksTips[v]);
  static String _rosette(num cx, num cy, num s, String tip) {
    final b = StringBuffer('<g transform="translate($cx $cy) scale($s)">');
    for (final a in [-80, -50, -20, 10, 40, 70, -65, 55]) {
      b.write('<path d="M0 0 C-12 -10 -10 -30 0 -38 C10 -30 12 -10 0 0 Z" fill="#8FBFA0" transform="rotate($a)"/>'
          '<path d="M0 -38 C-3 -34 -3 -30 0 -28 C3 -30 3 -34 0 -38 Z" fill="$tip" transform="rotate($a)"/>');
    }
    for (final a in [-30, 0, 30]) {
      b.write('<path d="M0 0 C-7 -6 -6 -18 0 -22 C6 -18 7 -6 0 0 Z" fill="#B5DCC2" transform="rotate($a)"/>');
    }
    return '$b</g>';
  }

  static const hyacinths = ['#8FA8E0', '#F2A0B8', '#FFFFFF'];
  static String hyacinth(int v) {
    final b = StringBuffer()
      ..write('<path d="M100 172 C82 152 78 124 84 100 C92 126 96 150 100 164 Z" fill="#5BB884"/>')
      ..write('<path d="M100 172 C118 152 122 128 116 106 C108 130 104 152 100 164 Z" fill="#7CCB9A"/>')
      ..write(_stem('M100 172 L100 70', width: 5));
    for (var row = 0; row < 7; row++) {
      final y = 72 + row * 9.0;
      final w = 14 - (row - 3).abs() * 1.6;
      for (final dx in [-w, 0, w]) {
        b.write('<g transform="translate(${_f(100 + dx)} ${_f(y)})">${_petals(5, 4, 2.6, 4, hyacinths[v])}</g>');
      }
    }
    return b.toString();
  }

  static const bunnyEars = ['#F7E8C8', '#F7D774', '#F2A7BE'];
  static String bunnyEar(int v) {
    final b = StringBuffer();
    for (final (x, y, rx, ry, a) in const [(100, 144, 24, 30, 0), (78, 104, 15, 20, -24), (122, 104, 15, 20, 24)]) {
      b.write('<ellipse cx="$x" cy="$y" rx="$rx" ry="$ry" fill="#7FC497" transform="rotate($a $x $y)"/>');
      for (var i = 0; i < 9; i++) {
        b.write('<circle cx="${_f(x + math.cos(i * 1.7) * rx * 0.6)}" cy="${_f(y + math.sin(i * 2.3) * ry * 0.6)}" r="1.8" fill="${bunnyEars[v]}"/>');
      }
    }
    b.write('<g transform="translate(100 112)">${_petals(6, 6, 4, 6, '#F2A7BE')}<circle r="3" fill="#FFF3B0"/></g>');
    return b.toString();
  }

  static const maidenhairs = ['#8FD3A8', '#7CCB9A', '#A8D86E'];
  static String maidenhair(int v) {
    final b = StringBuffer();
    for (final (dx, top) in const [(-34, 100), (-12, 80), (12, 78), (34, 98)]) {
      final x = 100 + dx;
      b.write(_stem('M100 172 C${100 + dx * 0.3} 140 $x ${top + 30} $x $top', colour: '#2B2A2A', width: 2));
      for (var t = 0.2; t <= 1.0; t += 0.16) {
        final px = 100 + (x - 100) * t, py = 172 - (172 - top) * t;
        for (final side in const [-1, 1]) {
          b.write('<path d="M0 0 C-6 -2 -9 -8 -6 -12 C-2 -12 2 -8 0 0 Z" fill="${maidenhairs[v]}" '
              'transform="translate(${_f(px + side * 6)} ${_f(py)}) rotate(${side * 60})"/>');
        }
      }
    }
    return b.toString();
  }

  static const pileas = ['#5BB884', '#4FAE78', '#7CCB9A'];
  static String pilea(int v) {
    final b = StringBuffer()..write(_stem('M100 172 C100 150 100 130 100 112', colour: '#7A6A48', width: 4));
    for (final (x, y, r) in const [(70, 112, 14), (130, 108, 15), (84, 86, 13), (118, 82, 14), (100, 66, 13), (100, 104, 12), (62, 140, 11), (138, 138, 11)]) {
      b
        ..write(_stem('M100 ${y + 20} Q${(100 + x) / 2} ${y + 6} $x $y', colour: '#7A9E5A', width: 2))
        ..write('<circle cx="$x" cy="$y" r="$r" fill="${pileas[v]}"/><circle cx="$x" cy="$y" r="2" fill="#B5DCC2"/>');
    }
    return b.toString();
  }

  static const magnolias = ['#F7CFDB', '#FFFFFF', '#C27BA0'];
  static String magnolia(int v) {
    final b = StringBuffer()
      ..write(_stem('M100 172 C98 150 104 132 96 108 M98 138 C112 128 122 118 128 100 M96 120 C84 110 76 98 72 86 M98 110 C100 96 104 86 106 74',
          colour: '#6E5A48', width: 7));
    for (final (x, y, a) in const [(128, 96, 20), (72, 82, -20), (106, 70, 0), (88, 100, -10), (118, 116, 30)]) {
      b.write('<g transform="translate($x $y) rotate($a)">'
          '<path d="M0 8 C-12 0 -10 -16 -2 -20 C0 -12 0 -4 0 8 Z" fill="${magnolias[v]}" stroke="#D99AB4" stroke-width="1"/>'
          '<path d="M0 8 C12 0 10 -16 2 -20 C0 -12 0 -4 0 8 Z" fill="${magnolias[v]}" stroke="#D99AB4" stroke-width="1"/>'
          '<path d="M0 8 C-4 -4 -2 -18 0 -22 C2 -18 4 -4 0 8 Z" fill="#FFFFFF" opacity="0.7"/></g>');
    }
    return b.toString();
  }

  static const clovers = ['#FFFFFF', '#F2A0B8', '#E8E0FF'];
  static String clover(int v) {
    final b = StringBuffer();
    String trefoil(num x, num y, num s) => '<g transform="translate($x $y) scale($s)">'
        '${[for (final a in [0, 120, 240]) '<path d="M0 0 C-10 -4 -12 -16 -6 -20 C-2 -22 0 -18 0 -14 C0 -18 2 -22 6 -20 C12 -16 10 -4 0 0 Z" fill="#5BB884" transform="rotate($a)"/>'].join()}'
        '<path d="M0 -4 l0 -8" stroke="#B5DCC2" stroke-width="1.4"/></g>';
    for (final (x, top, s) in const [(78, 140, 1.0), (122, 134, 1.1), (100, 118, 1.2)]) {
      b
        ..write(_stem('M100 172 Q${(100 + x) / 2} ${top + 20} $x $top', colour: '#5BB884', width: 2.5))
        ..write(trefoil(x, top, s));
    }
    b
      ..write(_stem('M100 172 C104 140 108 110 110 92', colour: '#5BB884', width: 2.5))
      ..write('<g transform="translate(110 86)">');
    for (var k = 0; k < 14; k++) {
      b.write('<ellipse cx="${_f(math.cos(k * 0.9) * 6)}" cy="${_f(math.sin(k * 0.9) * 6 - 2)}" rx="2.4" ry="3.6" fill="${clovers[v]}" stroke="#E0B8C8" stroke-width="0.8"/>');
    }
    b.write('</g>');
    return b.toString();
  }

  // ---------------- Summer ----------------

  static const zinnias = ['#F0607A', '#F7A83C', '#B77DE0'];
  static String zinnia(int v) {
    final c = zinnias[v];
    return '${_stem('M100 172 C98 140 102 108 100 80')}'
        '${_leaf(98, 146, 205)}${_leaf(102, 120, -25, length: 36, fill: '#7CCB9A')}'
        '<g transform="translate(100 72)">${_petals(16, 16, 5, 9, c)}${_petals(12, 9, 4, 6, c, offset: 15)}'
        '<circle r="6" fill="#F7D33C"/><circle r="3" fill="#8A5A35"/></g>';
  }

  static const aloes = ['#7FB59A', '#8FC4A9', '#6FA892'];
  static String aloe(int v) {
    final b = StringBuffer()
      ..write(_stem('M104 150 C110 120 112 96 112 70', colour: '#7A9E5A', width: 3));
    for (var y = 70.0; y < 96; y += 6) {
      b.write('<path d="M112 $y l-4 6 M112 $y l4 6" stroke="#F28C3C" stroke-width="2.6" stroke-linecap="round"/>');
    }
    for (final a in [-70, -45, -20, 5, 30, 55, 75]) {
      final (tx, ty) = _polar(a, 70);
      b
        ..write('<path d="M${_f(100 - 8)} 170 Q${_f((100 + tx) / 2 - 6)} ${_f((170 + ty) / 2)} ${_f(tx)} ${_f(ty)} Q${_f((100 + tx) / 2 + 6)} ${_f((170 + ty) / 2)} 108 170 Z" fill="${aloes[v]}"/>')
        ..write('<circle cx="${_f((100 + tx) / 2)}" cy="${_f((170 + ty) / 2)}" r="1.6" fill="#E8EFD9"/>');
    }
    return b.toString();
  }

  static const cosmoses = ['#F2A0C8', '#FFFFFF', '#E0457B'];
  static String cosmos(int v) {
    final b = StringBuffer()..write(_stem('M100 172 C98 140 96 110 92 78 M98 130 C110 116 120 100 126 88', width: 3));
    for (final (x, y) in const [(78, 140), (122, 132), (84, 116), (116, 112)]) {
      b.write('<path d="M100 ${y + 10} L$x $y M${(100 + x) / 2} ${y + 5} l-4 -6 M${(100 + x) / 2} ${y + 5} l4 -6" stroke="#5BB884" stroke-width="1.6" stroke-linecap="round"/>');
    }
    for (final (x, y, s) in const [(92, 72, 1.0), (126, 84, 0.8)]) {
      b.write('<g transform="translate($x $y) scale($s)">');
      for (var k = 0; k < 8; k++) {
        b.write('<path d="M0 0 C-5 -6 -5 -16 -2 -20 L0 -17 L2 -20 C5 -16 5 -6 0 0 Z" fill="${cosmoses[v]}" stroke="#E0A0C0" stroke-width="0.8" transform="rotate(${k * 45})"/>');
      }
      b.write('<circle r="4" fill="#F7B733"/></g>');
    }
    return b.toString();
  }

  static const saguaros = ['#FFFFFF', '#F7D774', '#F2A7BE'];
  static String saguaro(int v) {
    final b = StringBuffer()
      ..write('<path d="M80 140 H66 C58 140 54 134 54 126 V104" fill="none" stroke="#5DBB7E" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"/>')
      ..write('<path d="M120 124 H134 C142 124 146 118 146 110 V90" fill="none" stroke="#5DBB7E" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"/>')
      ..write('<rect x="82" y="48" width="36" height="128" rx="18" fill="#5DBB7E"/>')
      ..write('<path d="M94 58 V168 M106 58 V168" stroke="#86D3A2" stroke-width="3" stroke-linecap="round" opacity="0.8"/>');
    for (final (x, y) in const [(100, 46), (54, 100), (146, 86)]) {
      b.write('<g transform="translate($x $y)">${_petals(6, 5, 3.6, 5, saguaros[v])}<circle r="2.4" fill="#F7B733"/></g>');
    }
    return b.toString();
  }

  static const basils = [('#5BB884', '#7CCB9A'), ('#7A3A5A', '#9C4C74'), ('#7CCB9A', '#A8DDBF')];
  static String basil(int v) {
    final (a, c) = basils[v];
    final b = StringBuffer()..write(_stem('M100 172 L100 80 M100 140 L80 116 M100 130 L120 104', colour: '#6B8F4E', width: 3.5));
    for (final (x, y, ang, fill) in [
      (100, 160, 210, a), (100, 156, -30, c), (100, 128, 200, c), (100, 124, -20, a), (100, 100, 220, a), (100, 96, -40, c),
      (80, 116, 230, a), (120, 104, -50, c), (100, 82, 260, c), (100, 80, -80, a),
    ]) {
      b.write('<g transform="translate($x $y) rotate($ang)"><path d="M0 0 C6 -10 22 -12 30 -2 C22 8 6 8 0 0 Z" fill="$fill"/>'
          '<path d="M2 -1 H26" stroke="#E9F6EE" stroke-width="1.2" opacity="0.7"/></g>');
    }
    return b.toString();
  }

  static const birdsOfParadise = [('#F28C1E', '#3F6AD6'), ('#F7D33C', '#5A7AE0'), ('#E8604A', '#2F5AB0')];
  static String birdOfParadise(int v) {
    final (petal, tongue) = birdsOfParadise[v];
    final b = StringBuffer();
    for (final (x, y, a) in const [(70, 120, -30), (130, 116, 30), (88, 100, -10), (116, 96, 12)]) {
      b
        ..write(_stem('M100 172 Q100 ${y + 30} $x ${y + 24}', colour: '#4F8F62', width: 3))
        ..write('<ellipse cx="$x" cy="$y" rx="10" ry="26" fill="#3F8A62" transform="rotate($a $x $y)"/>'
            '<path d="M$x ${y - 24} V${y + 24}" stroke="#A8DDBF" stroke-width="1.6" transform="rotate($a $x $y)"/>');
    }
    b
      ..write(_stem('M100 172 C100 130 102 96 104 74', colour: '#4F8F62', width: 4))
      ..write('<path d="M104 74 C116 70 132 72 140 78 C126 80 114 80 104 78 Z" fill="#3F7A5A"/>')
      ..write('<path d="M114 74 L110 52 L118 72 L124 50 L126 72 L134 56 L132 74 Z" fill="$petal"/>')
      ..write('<path d="M120 76 L140 66" stroke="$tongue" stroke-width="4" stroke-linecap="round"/>');
    return b.toString();
  }

  static const palms = ['#5BB884', '#4FAE78', '#7CCB9A'];
  static String palm(int v) {
    final b = StringBuffer()..write('<path d="M96 176 C94 150 98 116 106 86 L112 88 C106 118 104 150 106 176 Z" fill="#B08A5E"/>');
    for (var y = 100.0; y < 170; y += 12) {
      b.write('<path d="M${_f(98 + (176 - y) * 0.06)} $y h10" stroke="#8A6A44" stroke-width="2"/>');
    }
    for (final a in [-80, -45, -10, 25, 60, 95]) {
      b.write('<g transform="translate(109 86) rotate($a)">'
          '<path d="M0 0 C14 -8 34 -6 48 6 C34 2 16 4 0 0 Z" fill="${palms[v]}"/>'
          '${[for (var t = 8; t < 44; t += 8) '<path d="M$t ${_f(-2 + t * 0.06)} l4 8" stroke="${palms[v]}" stroke-width="3" stroke-linecap="round"/>'].join()}</g>');
    }
    b.write('<circle cx="104" cy="94" r="5" fill="#8A6A44"/><circle cx="114" cy="96" r="5" fill="#7A5A3A"/>');
    return b.toString();
  }

  static const peaShoots = ['#FFFFFF', '#E8A0D6', '#B7A0E8'];
  static String peaShoot(int v) {
    final b = StringBuffer()
      ..write(_stem('M100 172 C96 150 104 130 100 108 C96 94 104 86 100 76', width: 4))
      ..write(_leaf(100, 150, 200, length: 30, fill: '#7CCB9A'))
      ..write(_leaf(100, 130, -20, length: 30))
      ..write(_leaf(100, 108, 210, length: 26, fill: '#7CCB9A'))
      ..write('<path d="M100 96 C112 92 116 82 110 78 C106 76 104 82 108 84" fill="none" stroke="#5BB884" stroke-width="2" stroke-linecap="round"/>'
          '<path d="M100 116 C86 112 82 102 88 98 C92 96 94 102 90 104" fill="none" stroke="#5BB884" stroke-width="2" stroke-linecap="round"/>');
    b.write('<g transform="translate(100 72)"><path d="M0 4 C-10 -2 -10 -14 0 -16 C10 -14 10 -2 0 4 Z" fill="${peaShoots[v]}" stroke="#D0B0E0" stroke-width="1"/>'
        '<path d="M0 4 C-5 0 -5 -6 0 -8 C5 -6 5 0 0 4 Z" fill="#F7E8FF"/></g>');
    return b.toString();
  }

  // ---------------- Autumn ----------------

  static const marigolds = [('#F28C1E', '#F7B733'), ('#E0622E', '#F28C1E'), ('#F7C948', '#FFE08A')];
  static String marigold(int v) {
    final (outer, inner) = marigolds[v];
    final b = StringBuffer()
      ..write(_stem('M100 172 C98 140 102 110 100 82 M100 130 C90 118 84 106 80 96 M100 120 C110 108 118 98 122 92', colour: '#5E8C4A', width: 4))
      ..write(_leaf(98, 146, 205, fill: '#6B8F4E'))
      ..write(_leaf(102, 122, -25, length: 34, fill: '#7A9E5A'));
    for (final (x, y, s) in const [(100, 76, 1.1), (80, 96, 0.8), (122, 92, 0.8)]) {
      b.write('<g transform="translate($x $y) scale($s)">${_petals(12, 10, 6, 8, outer)}${_petals(10, 5, 5, 6, inner, offset: 18)}<circle r="3" fill="#C9602E"/></g>');
    }
    return b.toString();
  }

  static const kalanchoes = ['#F2795C', '#F2C14E', '#E8607E'];
  static String kalanchoe(int v) {
    final b = StringBuffer();
    for (final a in [-60, -30, 0, 30, 60]) {
      b.write('<path d="M100 166 C88 154 90 136 100 128 C110 136 112 154 100 166 Z" fill="#4F8F62" transform="rotate($a 100 166)"/>');
    }
    b.write(_stem('M100 140 L90 96 M100 140 L110 92 M100 140 L100 84', colour: '#4F8F62', width: 3));
    for (final (x, y) in const [(90, 92), (110, 88), (100, 80)]) {
      for (final (dx, dy) in const [(-5, 0), (5, 0), (0, -5), (0, 4), (-3, -3), (4, -3)]) {
        b.write('<circle cx="${x + dx}" cy="${y + dy}" r="3.8" fill="${kalanchoes[v]}"/>');
      }
    }
    return b.toString();
  }

  static const dahlias = [('#B5304A', '#D9384F', '#E8604A'), ('#7A2E5A', '#9C3C6C', '#C2507E'), ('#F28C3C', '#F7A85C', '#FFD08A')];
  static String dahlia(int v) {
    final (a, c, d) = dahlias[v];
    return '${_stem('M100 172 C98 140 102 108 100 80', colour: '#3F7A5A')}'
        '${_leaf(98, 144, 205, fill: '#3F7A5A')}${_leaf(102, 118, -25, length: 36, fill: '#4F8F62')}'
        '<g transform="translate(100 72)">${_petals(14, 18, 6, 11, a)}${_petals(12, 11, 5, 8, c, offset: 15)}${_petals(8, 5, 4, 5, d, offset: 22)}</g>';
  }

  static const goldenBarrels = ['#F2C14E', '#F7E08A', '#E89B3C'];
  static String goldenBarrel(int v) {
    final spine = goldenBarrels[v];
    final b = StringBuffer()..write('<circle cx="100" cy="140" r="36" fill="#5DBB7E"/>');
    for (final dx in [-24, -12, 0, 12, 24]) {
      b
        ..write('<path d="M${100 + dx} 106 C${_f(100 + dx * 1.3)} 128 ${_f(100 + dx * 1.3)} 154 ${100 + dx} 174" fill="none" stroke="#86D3A2" stroke-width="3"/>')
        ..write('<path d="M${100 + dx} ${_f(110 + dx.abs() * 0.3)} l-3 -6 M${100 + dx} ${_f(110 + dx.abs() * 0.3)} l3 -6" stroke="$spine" stroke-width="2.4" stroke-linecap="round"/>');
    }
    b.write('<ellipse cx="100" cy="106" rx="14" ry="5" fill="$spine"/>');
    return b.toString();
  }

  static const brackens = [('#C9823F', '#D7713F', '#E39B5A', '#F0B657'), ('#B5654A', '#C9824A', '#D9A060', '#E8B87A'), ('#9C8A3A', '#B5A04A', '#C9B45A', '#DCC86A')];
  static String bracken(int v) {
    final cs = brackens[v];
    final b = StringBuffer();
    for (final (dx, top) in const [(-40, 96), (-12, 72), (18, 76), (42, 100)]) {
      b.write(_stem('M100 172 Q${_f(100 + dx * 0.3)} 120 ${100 + dx} $top', colour: '#8A5E3C', width: 3));
      for (final (i, t) in const [0.35, 0.5, 0.65, 0.8, 0.92].indexed) {
        final x = 100 + dx * t, y = 172 - (172 - top) * t;
        final c = [cs.$1, cs.$2, cs.$3, cs.$4][math.min(i, 3)];
        b.write('<path d="M${_f(x)} ${_f(y)} l-10 -4 M${_f(x)} ${_f(y)} l10 -4" stroke="$c" stroke-width="5" stroke-linecap="round"/>');
      }
    }
    return b.toString();
  }

  static const rubberPlants = [('#4A2E3A', '#5A3A4A', '#7A3A4A'), ('#2F5A3A', '#3F6A4A', '#4F7A5A'), ('#3A4A2E', '#5A6A3A', '#8A6A3A')];
  static String rubberPlant(int v) {
    final (a, c, d) = rubberPlants[v];
    final b = StringBuffer()..write(_stem('M100 172 C100 140 100 110 100 70', colour: '#5A3A2A', width: 5));
    for (final (dx, y, ang, fill) in [(-16, 150, -50, a), (16, 138, 50, c), (-14, 118, -40, a), (14, 100, 40, d), (0, 72, 0, d)]) {
      b.write('<ellipse cx="${100 + dx}" cy="$y" rx="11" ry="22" fill="$fill" transform="rotate($ang ${100 + dx} $y)"/>'
          '<path d="M${100 + dx} ${y - 20} V${y + 20}" stroke="#E8D8C8" stroke-width="1.2" opacity="0.5" transform="rotate($ang ${100 + dx} $y)"/>');
    }
    b.write('<path d="M100 56 C96 62 96 70 100 74 C104 70 104 62 100 56 Z" fill="#D9384F"/>');
    return b.toString();
  }

  static const ginkgos = [('#F2C14E', '#F7D774', '#E8B04A'), ('#E8A040', '#F2B84B', '#D9902E'), ('#C9C24A', '#DCD46A', '#B5AE3A')];
  static String ginkgo(int v) {
    final (a, c, d) = ginkgos[v];
    final b = StringBuffer()
      ..write(_stem('M100 172 C98 150 104 132 96 108 M98 138 C110 130 118 124 124 112', colour: '#7A5A3A', width: 9));
    for (final (x, y, ang, fill) in [
      (98, 96, 0, a), (84, 90, -30, c), (114, 92, 30, d), (78, 108, -60, a), (122, 108, 60, c), (98, 78, 0, d), (110, 80, 20, a), (86, 78, -20, c), (104, 108, 10, d),
      (92, 66, -10, a), (116, 66, 14, c), (72, 92, -45, d), (128, 90, 45, a),
    ]) {
      b.write('<path d="M0 0 L-12 -16 C-6 -20 6 -20 12 -16 Z" fill="$fill" transform="translate($x $y) rotate($ang)"/>');
    }
    b.write('<path d="M0 0 L-6 -8 C-3 -10 3 -10 6 -8 Z" fill="$a" transform="translate(130 172) rotate(30)"/>');
    return b.toString();
  }

  static const pumpkins = [('#F28C1E', '#D9701A'), ('#F4EBDD', '#D9CBB4'), ('#8FBF7A', '#6FA05A')];
  static String pumpkinSprout(int v) {
    final (body, rib) = pumpkins[v];
    return '${_stem('M100 172 C98 150 102 130 100 112')}'
        '<path d="M100 120 C80 108 72 120 78 132 C86 130 94 126 100 120 Z M100 112 C122 100 130 112 124 124 C116 122 108 118 100 112 Z" fill="#5BB884"/>'
        '${_stem('M100 160 C120 160 128 150 130 140', colour: '#5BB884', width: 2.5)}'
        '<g transform="translate(124 162)"><ellipse rx="16" ry="12" fill="$body"/>'
        '<path d="M-7 -11 C-9 0 -9 6 -7 11 M7 -11 C9 0 9 6 7 11" stroke="$rib" stroke-width="2" fill="none"/>'
        '<path d="M0 -11 L2 -18" stroke="#5E8C4A" stroke-width="3" stroke-linecap="round"/></g>';
  }

  // ---------------- Winter ----------------

  static const winterJasmines = ['#F7D33C', '#FFF0A0', '#F7B733'];
  static String winterJasmine(int v) {
    final b = StringBuffer()
      ..write(_stem('M100 172 C90 130 70 110 56 90 M100 172 C106 130 126 108 146 96 M100 172 C100 130 98 100 102 70', colour: '#5E7F4A', width: 3));
    for (final (x, y) in const [(60, 96), (70, 108), (84, 124), (140, 100), (128, 112), (116, 126), (102, 74), (100, 94), (98, 116), (92, 140), (108, 144)]) {
      b.write('<g transform="translate($x $y)">${_petals(6, 5, 3, 5, winterJasmines[v])}<circle r="2" fill="#E8A417"/></g>');
    }
    return b.toString();
  }

  static const haworthias = [('#2F6A4E', '#3F7A5A', '#4F8F62'), ('#3F5A4A', '#4F6A5A', '#5F7A6A'), ('#2F5A5A', '#3F6A6A', '#4F7A7A')];
  static String haworthia(int v) {
    final (a, c, d) = haworthias[v];
    final b = StringBuffer();
    for (final (ang, fill) in [(-72, a), (72, a), (-48, c), (48, c), (-24, d), (24, d), (0, c)]) {
      final (x1, y1) = _polar(ang - 12, 30);
      final (x2, y2) = _polar(ang, 54);
      final (x3, y3) = _polar(ang, 60);
      final (x4, y4) = _polar(ang + 12, 30);
      final (x5, y5) = _polar(ang + 8, 12);
      b.write('<path d="M100 170 C${_f(x1)} ${_f(y1)} ${_f(x2)} ${_f(y2)} ${_f(x3)} ${_f(y3)} C${_f(x4)} ${_f(y4)} ${_f(x5)} ${_f(y5)} 100 170 Z" fill="$fill"/>');
      final (s1, t1) = _polar(ang, 16);
      final (s2, t2) = _polar(ang, 36);
      b.write('<path d="M${_f(s1)} ${_f(t1)} L${_f(s2)} ${_f(t2)}" stroke="#E8EFD9" stroke-width="2.4" stroke-dasharray="2.5 4" stroke-linecap="round"/>');
    }
    return b.toString();
  }

  static const cyclamens = ['#E86A9A', '#FFFFFF', '#C2307A'];
  static String cyclamen(int v) {
    final b = StringBuffer();
    for (final (x, y, a) in const [(78, 160, -30), (122, 160, 30), (100, 152, 0)]) {
      b.write('<g transform="translate($x $y) scale(1.6) rotate($a)">'
          '<path d="M0 10 C-14 2 -14 -10 -6 -12 C-2 -13 0 -9 0 -6 C0 -9 2 -13 6 -12 C14 -10 14 2 0 10 Z" fill="#3F7A5A"/>'
          '<path d="M0 6 C-6 2 -7 -4 -4 -7 C-2 -4 2 -4 4 -7 C7 -4 6 2 0 6 Z" fill="#7FA88E" opacity="0.6"/></g>');
    }
    for (final dx in const [-14, 2, 16]) {
      b
        ..write(_stem('M100 160 C${100 + dx} 130 ${100 + dx} 110 ${_f(100 + dx * 1.4)} 96', colour: '#7A5A6A', width: 2.5))
        ..write('<path d="M0 6 C-6 -6 -10 -18 -4 -22 C0 -14 0 -14 4 -22 C10 -18 6 -6 0 6 Z" fill="${cyclamens[v]}" stroke="#D0809E" stroke-width="1" '
            'transform="translate(${_f(100 + dx * 1.4)} 92)"/>');
    }
    return b.toString();
  }

  static const snowballs = ['#E0457B', '#F7B733', '#B77DE0'];
  static String snowballCactus(int v) {
    final b = StringBuffer();
    for (final (x, y, r) in const [(82, 150, 22), (118, 148, 24), (100, 118, 22)]) {
      b.write('<circle cx="$x" cy="$y" r="$r" fill="#EEF2EA"/><circle cx="$x" cy="$y" r="$r" fill="none" stroke="#C9D6C2" stroke-width="2" stroke-dasharray="1 4"/>');
    }
    for (final (x, y) in const [(92, 98), (100, 96), (108, 98)]) {
      b.write('<circle cx="$x" cy="$y" r="4.4" fill="${snowballs[v]}"/>');
    }
    return b.toString();
  }

  static const staghorns = ['#6FA892', '#8FBF9A', '#5E9C84'];
  static String staghorn(int v) {
    final b = StringBuffer('<ellipse cx="100" cy="160" rx="26" ry="14" fill="#9C8B6A"/>');
    for (final a in const [-50, -20, 15, 45]) {
      b.write('<g transform="translate(100 150) rotate($a)"><path d="M0 0 C-6 -30 -4 -50 0 -60 C4 -50 6 -30 0 0 Z '
          'M0 -40 C-10 -50 -18 -54 -24 -54 C-18 -46 -10 -42 0 -40 Z M0 -46 C10 -56 18 -60 24 -60 C18 -52 10 -48 0 -46 Z" fill="${staghorns[v]}"/></g>');
    }
    return b.toString();
  }

  static const zzs = [('#2F6A4E', '#3F7A5A'), ('#3F7A4A', '#5A8F5A'), ('#1F3A2E', '#2F4A3A')];
  static String zzPlant(int v) {
    final (a, c) = zzs[v];
    final b = StringBuffer();
    for (final (dx, top) in const [(-26, 80), (0, 64), (26, 82)]) {
      b.write(_stem('M100 172 C${_f(100 + dx * 0.3)} 140 ${100 + dx} 120 ${100 + dx} $top', colour: '#3F6A4A', width: 3));
      for (final t in const [0.0, 0.33, 0.66, 1.0]) {
        final x = 100 + dx * (0.5 + t * 0.5), y = top + 20 + t * 40;
        b
          ..write('<ellipse cx="${_f(x - 7)}" cy="${_f(y)}" rx="7" ry="4" fill="$a" transform="rotate(-30 ${_f(x - 7)} ${_f(y)})"/>')
          ..write('<ellipse cx="${_f(x + 7)}" cy="${_f(y - 4)}" rx="7" ry="4" fill="$c" transform="rotate(30 ${_f(x + 7)} ${_f(y - 4)})"/>');
      }
    }
    return b.toString();
  }

  static const birches = ['#D9C26A', '#C9D6E0', '#E8B04A'];
  static String birch(int v) {
    const branches = 'M100 176 L100 100 M100 130 L118 100 M100 118 L84 92 M100 104 L108 80';
    final b = StringBuffer()
      ..write(_stem(branches, colour: '#9AA0A6', width: 11))
      ..write(_stem(branches, colour: '#F4F1EA', width: 7));
    for (final (x, y) in const [(100, 164), (100, 148), (100, 132), (100, 116), (110, 110), (92, 104)]) {
      b.write('<path d="M${x - 4} $y h8" stroke="#3A3A3A" stroke-width="2.4" stroke-linecap="round"/>');
    }
    b.write('<path d="M78 92 C84 84 92 86 94 92 Z M110 84 C116 76 124 78 126 84 Z M104 80 C108 74 112 74 114 80 Z" fill="#FFFFFF" stroke="#C9D6E0" stroke-width="1.2"/>');
    for (final (x, y) in const [(86, 96), (122, 90), (112, 78)]) {
      b.write('<circle cx="$x" cy="$y" r="2.4" fill="${birches[v]}"/>');
    }
    return b.toString();
  }

  static const mistletoes = ['#D9384F', '#3F7A5A', '#D9A43C'];
  static String mistletoe(int v) {
    final b = StringBuffer()
      ..write(_stem('M100 172 C98 146 102 124 100 104 M100 130 L82 112 M100 120 L118 104', colour: '#7A8A4A', width: 3));
    for (final (x, y, a) in const [(100, 150, 200), (100, 140, -20), (82, 112, 220), (118, 104, -40)]) {
      b.write(_leaf(x, y, a, length: 26, fill: '#8FAA6A'));
    }
    for (final (x, y) in const [(96, 102), (104, 98), (100, 108), (84, 108), (118, 100)]) {
      b.write('<circle cx="$x" cy="$y" r="4.6" fill="#F7F4E8" stroke="#D9D3C0" stroke-width="1"/>');
    }
    b.write('<path d="M92 92 C96 84 104 84 108 92 L100 98 Z" fill="${mistletoes[v]}"/>');
    return b.toString();
  }
}
