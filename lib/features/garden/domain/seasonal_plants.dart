import 'dart:math' as math;

/// The season a day falls in, for which plant it grows.
enum Season {
  spring,
  summer,
  autumn,
  winter;

  /// Countries in the southern hemisphere's temperate belt, where October
  /// is spring. Everywhere else, tropics included, follows the northern
  /// calendar so the seasons still show.
  static const southernCountries = {'AU', 'NZ', 'AR', 'CL', 'UY', 'PY', 'ZA', 'LS', 'SZ', 'NA', 'BW', 'BR'};

  static bool isSouthern(String? countryCode) => southernCountries.contains(countryCode?.toUpperCase());

  /// Whether this device is in the south; set once at start-up from the
  /// phone's region.
  static bool southern = false;

  /// Meteorological seasons: spring is March to May in the north,
  /// September to November in the south.
  static Season ofMonth(int month, {bool? southern}) {
    final m = (southern ?? Season.southern) ? (month + 5) % 12 + 1 : month;
    return switch (m) {
      3 || 4 || 5 => spring,
      6 || 7 || 8 => summer,
      9 || 10 || 11 => autumn,
      _ => winter,
    };
  }

  static Season of(DateTime day, {bool? southern}) => ofMonth(day.month, southern: southern);
}

/// The varieties each seasonal plant comes in: colours a day picks by its
/// place in the year, so neighbouring days differ.
const varietyCount = 3;

int varietyOf(DateTime day) => day.difference(DateTime(day.year)).inDays % varietyCount;

/// Drawings of the plants a kind of day grows outside summer, in the same
/// 200 × 240 box as the summer plants: the stem meets the soil at
/// (100, 176). Each takes its variety's colours.
class SeasonalArt {
  SeasonalArt._();

  static String _f(num n) => n.toStringAsFixed(1);

  static String _petals(int n, num r, num rx, num ry, String fill, {num offset = 0}) => [
        for (var k = 0; k < n; k++)
          '<ellipse cx="0" cy="${-r}" rx="$rx" ry="$ry" fill="$fill" transform="rotate(${_f(offset + k * 360 / n)})"/>',
      ].join();

  static String _stem(String d, {String colour = '#3F9E6A', num width = 5}) =>
      '<path d="$d" fill="none" stroke="$colour" stroke-width="$width" stroke-linecap="round"/>';

  static String _leaf(num x, num y, num angle, {num length = 40, String fill = '#5BB884'}) =>
      '<path d="M0 0 C${_f(length * 0.25)} -12 ${_f(length * 0.75)} -12 $length 0 C${_f(length * 0.75)} 10 ${_f(length * 0.25)} 10 0 0 Z" '
      'fill="$fill" transform="translate($x $y) rotate($angle)"/>';

  static String _blade(bool left, {String fill = '#5BB884', num top = 92}) => left
      ? '<path d="M100 172 C80 150 74 ${top + 26} 82 $top C90 ${top + 28} 96 150 100 164 Z" fill="$fill"/>'
      : '<path d="M100 172 C120 150 126 ${top + 26} 118 $top C110 ${top + 28} 104 150 100 164 Z" fill="$fill"/>';

  // ---- Exercise: sunny flowers ----

  static const daffodils = [('#FFF3B0', '#F7B733'), ('#FFFFFF', '#F7B733'), ('#FFE066', '#F08A24')];
  static String daffodil(int v) {
    final (petal, cup) = daffodils[v];
    return '${_blade(true, top: 96)}${_blade(false, fill: '#7CCB9A', top: 104)}'
        '${_stem('M100 172 C98 140 102 100 100 72')}'
        '<g transform="translate(100 64)">${_petals(6, 14, 8, 14, petal)}'
        '<circle r="9" fill="$cup"/><circle r="5" fill="${_darker(cup)}"/></g>';
  }

  static const chrysanthemums = [('#E8823F', '#F0A257'), ('#C2410C', '#E06A3F'), ('#F2C14E', '#F7D774')];
  static String chrysanthemum(int v) {
    final (outer, inner) = chrysanthemums[v];
    return '${_stem('M100 172 C96 136 104 100 100 66', colour: '#5E8C4A')}'
        '${_leaf(98, 140, 205, fill: '#7A9E5A')}${_leaf(102, 116, -25, length: 34, fill: '#6B8F4E')}'
        '<g transform="translate(100 60)">${_petals(20, 16, 3.4, 13, outer)}${_petals(14, 9, 3, 9, inner, offset: 12)}'
        '<circle r="5" fill="${_darker(outer)}"/></g>';
  }

  static const snowdrops = ['#FFFFFF', '#F4F7FF', '#FFFFFF'];
  static String snowdrop(int v) {
    final bells = v == 2 ? [(92.0, 0.0), (108.0, 18.0)] : [(96.0, 0.0)];
    final b = StringBuffer()
      ..write(_blade(true, fill: '#6FA892', top: 88))
      ..write(_blade(false, fill: '#8DBBA8', top: 100));
    for (final (x, drop) in bells) {
      b
        ..write(_stem('M$x 172 C$x 120 ${x - 2} 76 ${x + 18} ${68 + drop}', colour: '#4D8C74', width: 5))
        ..write('<g transform="translate(${x + 22} ${80 + drop}) scale(1.5)">'
            '<ellipse cx="0" cy="-8" rx="5" ry="3" fill="#6FA892"/>'
            '<path d="M-11 -4 C-12 10 -6 20 0 22 C6 20 12 10 11 -4 C6 -8 -6 -8 -11 -4 Z" fill="${snowdrops[v]}" stroke="#B9C9D6" stroke-width="1.4"/>'
            '<path d="M-4 14 C-2 18 2 18 4 14" fill="none" stroke="#7CCB9A" stroke-width="2.4" stroke-linecap="round"/></g>');
    }
    b.write('<ellipse cx="100" cy="174" rx="30" ry="5" fill="#FFFFFF" opacity="0.9"/>');
    return b.toString();
  }

  // ---- Rest: succulents ----

  static const echeverias = ['#F28C6B', '#F2B84B', '#E77FA3'];
  static String echeveria(int v) {
    final b = StringBuffer();
    for (final a in [-70, -46, -22, 0, 22, 46, 70]) {
      b.write('<path d="M100 170 C88 156 90 134 100 124 C110 134 112 156 100 170 Z" fill="#9FCFB8" transform="rotate($a 100 170)"/>');
    }
    for (final a in [-34, 0, 34]) {
      b.write('<path d="M100 166 C93 156 94 142 100 136 C106 142 107 156 100 166 Z" fill="#C3E3D2" transform="rotate($a 100 166)"/>');
    }
    b.write(_stem('M104 150 C120 120 132 96 144 84', colour: '#C47A6A', width: 3.5));
    for (final (x, y) in const [(132, 104), (140, 92), (147, 82), (126, 114)]) {
      b.write('<path d="M${x - 5} $y C${x - 5} ${y + 10} ${x + 5} ${y + 10} ${x + 5} $y Z" fill="${echeverias[v]}"/>');
    }
    return b.toString();
  }

  static const sedums = [('#D9667F', '#E895A6'), ('#B5475E', '#D9667F'), ('#E8A0B4', '#F4C6D3')];
  static String sedum(int v) {
    final (flower, light) = sedums[v];
    final b = StringBuffer();
    for (final (dx, top) in const [(-26, 96), (0, 84), (26, 98)]) {
      b.write(_stem('M100 172 C${100 + dx * 0.3} 140 ${100 + dx} 120 ${100 + dx} $top', colour: '#7A9E6A', width: 4));
      for (var t = 0; t < 3; t++) {
        final y = 150 - t * 18 - (dx == 0 ? 6 : 0);
        final x = 100 + dx * (0.45 + t * 0.2);
        b
          ..write('<ellipse cx="${_f(x - 8)}" cy="$y" rx="9" ry="5" fill="#8DBB8A" transform="rotate(-25 ${_f(x - 8)} $y)"/>')
          ..write('<ellipse cx="${_f(x + 8)}" cy="${y - 4}" rx="9" ry="5" fill="#9FC79A" transform="rotate(25 ${_f(x + 8)} ${y - 4})"/>');
      }
      final cx = 100 + dx;
      b.write('<ellipse cx="$cx" cy="${top - 4}" rx="17" ry="9" fill="$flower"/>');
      for (final (ox, oy) in const [(-8, -6), (0, -9), (8, -6), (-4, -2), (5, -1)]) {
        b.write('<circle cx="${cx + ox}" cy="${top + oy}" r="3" fill="$light"/>');
      }
    }
    return b.toString();
  }

  static const jades = ['#D9534F', '#E8A040', '#3F8A62'];
  static String jade(int v) {
    final edge = jades[v];
    final b = StringBuffer()
      ..write(_stem('M100 172 C98 150 100 132 94 112 M98 140 C110 130 116 120 120 106 M96 124 C86 116 80 106 78 96',
          colour: '#7A6A48', width: 8));
    for (final (x, y, a) in const [
      (94, 104, -20), (82, 100, -50), (106, 98, 20), (122, 98, 30), (128, 108, 60),
      (72, 92, -70), (78, 112, -100), (114, 112, 80), (90, 92, 0), (118, 88, 10),
    ]) {
      b.write('<ellipse cx="$x" cy="$y" rx="11" ry="7" fill="#4F8F62" stroke="$edge" stroke-width="2" transform="rotate($a $x $y)"/>');
    }
    return b.toString();
  }

  // ---- People: flowers to share ----

  static const hibiscuses = [('#F0607A', '#FFD45C'), ('#F59E3C', '#FFE9A8'), ('#F7A8C4', '#FFFFFF')];
  static String hibiscus(int v) {
    final (petal, stamen) = hibiscuses[v];
    return '${_stem('M100 172 C98 140 102 110 100 80')}'
        '${_leaf(98, 146, 200, fill: '#3F9E6A')}${_leaf(102, 124, -20, length: 36)}${_leaf(98, 104, 210, length: 30, fill: '#7CCB9A')}'
        '<g transform="translate(100 70)">${_petals(5, 15, 15, 17, petal)}'
        '<circle r="6" fill="${_darker(petal)}"/>'
        '<path d="M0 0 L12 -16" stroke="$stamen" stroke-width="3" stroke-linecap="round"/><circle cx="12" cy="-17" r="3" fill="$stamen"/></g>';
  }

  static const asters = ['#A88BE0', '#7D9BE8', '#E8A0D6'];
  static String aster(int v) {
    final b = StringBuffer()
      ..write(_stem('M100 172 C100 140 100 110 100 84 M100 130 C88 118 80 104 76 92 M100 120 C112 106 120 96 126 84',
          colour: '#5E8C4A', width: 4))
      ..write(_leaf(100, 152, 200, length: 30, fill: '#7A9E5A'))
      ..write(_leaf(100, 140, -20, length: 30, fill: '#6B8F4E'));
    for (final (x, y, s) in const [(100, 78, 1.0), (74, 88, 0.8), (128, 80, 0.85)]) {
      b.write('<g transform="translate($x $y) scale($s)">${_petals(14, 11, 2.6, 9, asters[v])}<circle r="5" fill="#F7B733"/></g>');
    }
    return b.toString();
  }

  static const poinsettias = ['#D9384F', '#F2EDE4', '#F07FA0'];
  static String poinsettia(int v) {
    final bract = poinsettias[v];
    final b = StringBuffer()..write(_stem('M100 172 C100 150 100 130 100 110', colour: '#3F7A5A', width: 5));
    for (final a in [-60, 0, 60, 120, 180, 240]) {
      b.write('<path d="M100 150 C90 140 88 124 100 114 C112 124 110 140 100 150 Z" fill="#3F7A5A" transform="rotate(${a + 30} 100 136)"/>');
    }
    b.write('<g transform="translate(100 100)">');
    for (var k = 0; k < 7; k++) {
      b.write('<path d="M0 0 C-9 -12 -8 -30 0 -38 C8 -30 9 -12 0 0 Z" fill="$bract" transform="rotate(${_f(k * 360 / 7)})"/>');
    }
    b.write('<circle r="4" fill="#F7D35C"/><circle cx="5" cy="3" r="2" fill="#9CC46A"/></g>');
    return b.toString();
  }

  // ---- Work: cacti ----

  static const barrels = ['#F2A7BE', '#FFD45C', '#F07B6A'];
  static String barrel(int v) {
    final b = StringBuffer()
      ..write('<path d="M58 170 C54 120 70 96 100 94 C130 96 146 120 142 170 Z" fill="#5DBB7E"/>');
    for (final x in [72, 86, 100, 114, 128]) {
      b.write('<path d="M$x 168 C${x - (100 - x) * 0.2} 130 ${x - (100 - x) * 0.1} 110 $x 100" fill="none" stroke="#86D3A2" stroke-width="3" opacity="0.8"/>');
    }
    for (var k = 0; k < 6; k++) {
      final a = (k / 6) * math.pi;
      final x = 100 + math.cos(a) * 28, y = 98 - math.sin(a) * 8;
      b.write('<g transform="translate(${_f(x)} ${_f(y)})">${_petals(5, 5, 4, 5, barrels[v])}<circle r="2.4" fill="#FFF3B0"/></g>');
    }
    return b.toString();
  }

  static const pricklyPears = ['#D9384F', '#9C3C8C', '#F28C3C'];
  static String pricklyPear(int v) {
    final b = StringBuffer();
    for (final (x, y, rx, ry, a) in const [
      (100, 140, 22, 32, 0.0), (76, 104, 16, 24, -30.0), (122, 100, 17, 25, 25.0), (100, 84, 14, 20, 5.0),
    ]) {
      b.write('<ellipse cx="$x" cy="$y" rx="$rx" ry="$ry" fill="#6FB98A" transform="rotate($a $x $y)"/>');
      for (final (dx, dy) in const [(-8, -8), (6, -12), (-4, 6), (8, 8), (0, -2)]) {
        b.write('<circle cx="${x + dx * rx / 20}" cy="${y + dy * ry / 28}" r="1.4" fill="#F1F8EC"/>');
      }
    }
    for (final (x, y) in const [(66, 84), (84, 82), (114, 78), (130, 80), (98, 64)]) {
      b.write('<ellipse cx="$x" cy="$y" rx="5" ry="7" fill="${pricklyPears[v]}"/>');
    }
    return b.toString();
  }

  static const christmasCacti = ['#E0457B', '#F2795C', '#C77DD8'];
  static String christmasCactus(int v) {
    final b = StringBuffer();
    for (final (dx, dir) in const [(-1, -1), (1, 1), (0, -1), (0, 1)]) {
      var x = 100.0 + dx * 6, y = 170.0;
      for (var s = 0; s < 4; s++) {
        final nx = x + dir * (dx == 0 ? 5 + s * 2 : 8 + s * 3), ny = y - 24 + s * (dx == 0 ? 1 : 5);
        b.write('<path d="M$x $y L${_f(nx)} ${_f(ny)}" stroke="#4FAE78" stroke-width="10" stroke-linecap="round"/>');
        x = nx;
        y = ny;
      }
      b.write('<g transform="translate(${_f(x + dir * 6)} ${_f(y + 4)}) rotate(${dir * 40})">'
          '<path d="M0 0 C-6 -6 -10 -16 -6 -22 C-2 -16 2 -16 6 -22 C10 -16 6 -6 0 0 Z" fill="${christmasCacti[v]}"/>'
          '<path d="M0 -14 L0 -26" stroke="${christmasCacti[v]}" stroke-width="2"/></g>');
    }
    return b.toString();
  }

  // ---- Study: ferns and herbs ----

  static const fiddleheads = ['#7CCB9A', '#9AD08A', '#6FBFA8'];
  static String fiddlehead(int v) {
    final leaf = fiddleheads[v];
    final b = StringBuffer();
    for (final (dx, h, curl) in const [(-28, 96, 1), (0, 70, -1), (28, 92, -1), (-12, 120, -1)]) {
      final x = 100 + dx;
      b
        ..write(_stem('M100 172 C${100 + dx * 0.3} 140 $x ${h + 30} $x ${h + 10}', colour: '#4FAE78', width: 4))
        ..write('<path d="M$x ${h + 10} C$x $h ${x + curl * 14} $h ${x + curl * 14} ${h + 10} '
            'C${x + curl * 14} ${h + 18} ${x + curl * 4} ${h + 18} ${x + curl * 5} ${h + 11}" fill="none" stroke="#4FAE78" stroke-width="4" stroke-linecap="round"/>');
      for (var t = 0; t < 3; t++) {
        final y = 150 - t * 14 - (120 - h) * 0.4;
        b
          ..write('<ellipse cx="${_f(x - 7 + dx * -0.05)}" cy="${_f(y)}" rx="6" ry="3" fill="$leaf" transform="rotate(-30 ${_f(x - 7)} ${_f(y)})"/>')
          ..write('<ellipse cx="${_f(x + 7)}" cy="${_f(y - 2)}" rx="6" ry="3" fill="$leaf" transform="rotate(30 ${_f(x + 7)} ${_f(y - 2)})"/>');
      }
    }
    return b.toString();
  }

  static const rosemaries = ['#8FA8E0', '#B9A3E8', '#FFFFFF'];
  static String rosemary(int v) {
    final b = StringBuffer();
    for (final (dx, top) in const [(-22, 88), (-8, 70), (8, 76), (22, 92)]) {
      final x = 100 + dx;
      b.write(_stem('M100 172 C${100 + dx * 0.4} 140 $x ${top + 40} $x $top', colour: '#6E7F5A', width: 3));
      for (var y = top + 8.0; y < 164; y += 9) {
        final along = (y - top) / (172 - top);
        final cx = x + (100 - x) * along * 0.6;
        b
          ..write('<path d="M${_f(cx)} $y l-9 -6" stroke="#5E8C6A" stroke-width="2.6" stroke-linecap="round"/>')
          ..write('<path d="M${_f(cx)} $y l9 -6" stroke="#7AA383" stroke-width="2.6" stroke-linecap="round"/>');
      }
      b.write('<circle cx="$x" cy="${top - 2}" r="3.4" fill="${rosemaries[v]}"/><circle cx="${x - 5}" cy="${top + 6}" r="2.6" fill="${rosemaries[v]}"/>');
    }
    return b.toString();
  }

  static const ivies = [('#3F7A5A', '#B9D8A8'), ('#4F8F62', '#F2EDE4'), ('#2F6A4E', '#8FBF7A')];
  static String ivy(int v) {
    final (leaf, vein) = ivies[v];
    final b = StringBuffer();
    String heart(num x, num y, num a, num s) => '<g transform="translate($x $y) rotate($a) scale($s)">'
        '<path d="M0 10 C-14 2 -14 -10 -6 -12 C-2 -13 0 -9 0 -6 C0 -9 2 -13 6 -12 C14 -10 14 2 0 10 Z" fill="$leaf"/>'
        '<path d="M0 8 V-6 M0 2 L-6 -4 M0 2 L6 -4" stroke="$vein" stroke-width="1.4" stroke-linecap="round"/></g>';
    b
      ..write(_stem('M100 172 C98 140 104 120 100 96', colour: '#5E7F4A', width: 3))
      ..write(_stem('M100 168 C76 168 60 186 56 214', colour: '#5E7F4A', width: 3))
      ..write(_stem('M100 168 C126 170 140 190 146 220', colour: '#5E7F4A', width: 3));
    for (final (x, y, a, s) in const [
      (100, 96, 0, 1.2), (90, 116, -30, 1.0), (110, 128, 30, 1.0), (94, 146, -20, 0.9),
      (70, 176, -60, 0.9), (58, 204, -80, 0.8), (130, 182, 60, 0.9), (144, 210, 80, 0.8),
    ]) {
      b.write(heart(x, y, a, s));
    }
    return b.toString();
  }

  // ---- Games: foliage plants ----

  static const calatheas = [('#3F8A62', '#A8DDBF', '#9C3C6C'), ('#2F6A4E', '#E8EFD9', '#7A2E5A'), ('#5E9C6A', '#CDEEDB', '#B5476E')];
  static String calathea(int v) {
    final (leaf, stripe, under) = calatheas[v];
    final b = StringBuffer();
    for (final (x, y, a) in const [(70, 112, -40), (130, 108, 40), (92, 88, -12), (112, 92, 14), (100, 128, 0)]) {
      b
        ..write(_stem('M100 172 Q100 ${y + 30} $x ${y + 26}', colour: '#6B8F5A', width: 3))
        ..write('<g transform="translate($x $y) rotate($a)">'
            '<ellipse rx="14" ry="26" fill="$under" transform="translate(2 2)"/>'
            '<ellipse rx="14" ry="26" fill="$leaf"/>'
            '<path d="M0 -24 V24 M0 -14 L-9 -18 M0 -14 L9 -18 M0 -2 L-11 -6 M0 -2 L11 -6 M0 10 L-9 6 M0 10 L9 6" stroke="$stripe" stroke-width="2.4" stroke-linecap="round"/></g>');
    }
    return b.toString();
  }

  static const crotons = [('#E06A3F', '#F7C948', '#3F7A4A'), ('#D9384F', '#F09A3E', '#5A4A2A'), ('#F2C14E', '#7CCB9A', '#3F8A62')];
  static String croton(int v) {
    final (a, c, d) = crotons[v];
    final b = StringBuffer()..write(_stem('M100 172 C100 150 100 130 100 104', colour: '#6B4E3A', width: 5));
    for (final (x, y, ang, fill) in [
      (100, 150, 200, d), (100, 146, -20, a), (100, 128, 210, a), (100, 124, -30, c), (100, 108, 190, c), (100, 104, -10, d), (100, 100, 260, a),
    ]) {
      b.write('<g transform="translate($x $y) rotate($ang)"><path d="M0 0 C10 -12 34 -12 46 0 C34 10 10 10 0 0 Z" fill="$fill"/>'
          '<path d="M2 0 H42" stroke="#FFF3B0" stroke-width="1.6" opacity="0.8"/></g>');
    }
    return b.toString();
  }

  static const snakePlants = [('#3F7A5A', '#9CC46A'), ('#2F5A4A', '#F2D27E'), ('#4F8F62', '#CDE6A8')];
  static String snakePlant(int v) {
    final (leaf, edge) = snakePlants[v];
    final b = StringBuffer();
    for (final (dx, h, lean) in const [(-26, 92, -10), (-10, 64, -4), (6, 56, 4), (22, 80, 10), (-2, 100, 0)]) {
      final x = 100 + dx;
      b.write('<path d="M${x - 8} 174 C${x - 9} 140 ${x + lean - 6} ${h + 20} ${x + lean} $h C${x + lean + 6} ${h + 20} ${x + 9} 140 ${x + 8} 174 Z" '
          'fill="$leaf" stroke="$edge" stroke-width="2.6"/>');
      for (var y = h + 20.0; y < 166; y += 14) {
        b.write('<path d="M${x - 5} ${_f(y)} q5 -4 10 0" fill="none" stroke="$edge" stroke-width="1.6" opacity="0.6"/>');
      }
    }
    return b.toString();
  }

  // ---- A big day: trees ----

  static const cherries = [('#F7CFDB', '#F2B8C9', '#FBDDE7'), ('#FFFFFF', '#F7E1E8', '#FBEFF3'), ('#F2A0B8', '#E58FAA', '#F7C1D1')];
  static String cherry(int v) {
    final (a, c, d) = cherries[v];
    final b = StringBuffer()
      ..write(_stem('M100 172 C98 150 104 132 96 108 M98 138 C110 130 118 124 124 112', colour: '#7A4E3A', width: 9));
    for (final (x, y, r, fill) in [(98, 96, 30, a), (122, 104, 24, c), (76, 108, 24, d), (110, 76, 22, a), (84, 82, 20, c)]) {
      b.write('<circle cx="$x" cy="$y" r="$r" fill="$fill"/>');
    }
    for (final (x, y) in const [(80, 92), (104, 84), (118, 100), (92, 110), (70, 104), (112, 70)]) {
      b.write('<circle cx="$x" cy="$y" r="3.4" fill="#E58FAA"/>');
    }
    b.write('<ellipse cx="78" cy="172" rx="5" ry="2.4" fill="$a"/><ellipse cx="128" cy="174" rx="5" ry="2.4" fill="$c"/>');
    return b.toString();
  }

  static const maples = [('#E06A3F', '#F09A3E', '#D9534F'), ('#D9384F', '#B5304A', '#E8604A'), ('#F2B84B', '#E8A040', '#F7D774')];
  static String maple(int v) {
    final (a, c, d) = maples[v];
    final b = StringBuffer()
      ..write(_stem('M100 172 C98 150 104 132 96 108 M98 138 C110 130 118 124 124 112', colour: '#6E4A33', width: 9));
    for (final (x, y, r, fill) in [(98, 96, 30, a), (122, 104, 24, c), (76, 108, 24, d), (110, 76, 22, c), (84, 82, 20, a)]) {
      b.write('<circle cx="$x" cy="$y" r="$r" fill="$fill"/>');
    }
    for (final (x, y, rot) in const [(74, 170, 20), (128, 172, -30), (140, 158, 60)]) {
      b.write('<path d="M0 -6 L2 -2 L6 -3 L3 1 L5 5 L0 3 L-5 5 L-3 1 L-6 -3 L-2 -2 Z" fill="$d" transform="translate($x $y) rotate($rot)"/>');
    }
    return b.toString();
  }

  static const pines = ['#3F8A62', '#2F6A4E', '#4F9A72'];
  static String pine(int v) {
    final g = pines[v];
    return '${_stem('M100 176 L100 154', colour: '#6E4A33', width: 9)}'
        '<path d="M100 54 L124 94 L112 94 L134 126 L118 126 L142 158 L58 158 L82 126 L66 126 L88 94 L76 94 Z" fill="$g"/>'
        '<path d="M100 54 L111 73 L89 73 Z M80 124 L90 116 L110 116 L120 124 Z M64 156 L78 146 L122 146 L136 156 Z" fill="#FFFFFF"/>'
        '<circle cx="100" cy="50" r="5" fill="#FFE29A"/>';
  }

  // ---- A bit of everything: seedlings ----

  static const seedlings = ['#F2A7BE', '#FFD45C', '#B7A0E8'];
  static String seedling(int v) {
    return '${_stem('M100 172 C96 140 104 108 100 78', width: 6)}'
        '${_leaf(98, 148, 205, length: 48, fill: '#7DCC9C')}${_leaf(102, 124, -25, length: 44, fill: '#9ADBB2')}'
        '<g transform="translate(100 74) scale(1.6)"><path d="M0 6 C-8 -2 -8 -14 0 -20 C8 -14 8 -2 0 6 Z" fill="${seedlings[v]}"/>'
        '<path d="M0 6 C-5 2 -6 -4 -4 -8 M0 6 C5 2 6 -4 4 -8" stroke="#5DB57E" stroke-width="2" fill="none" stroke-linecap="round"/></g>';
  }

  static const oaks = [('#E39B5A', '#C9823F'), ('#D7713F', '#B85A2E'), ('#C9A24A', '#A88A3A')];
  static String oak(int v) {
    final (a, c) = oaks[v];
    String lobed(num x, num y, num rot, String fill) => '<g transform="translate($x $y) rotate($rot)">'
        '<path d="M0 0 C4 -6 10 -4 12 -10 C16 -6 20 -8 24 -12 C26 -6 32 -6 36 -8 C34 -2 38 2 42 0 C36 6 30 4 26 10 C22 6 18 8 14 12 C12 6 6 6 0 0 Z" fill="$fill"/></g>';
    return '${_stem('M100 172 C98 146 102 120 100 96', colour: '#7A5A3A', width: 4)}'
        '${lobed(100, 146, 200, a)}${lobed(100, 124, -20, c)}${lobed(100, 100, 250, a)}'
        '<g transform="translate(122 166)"><ellipse rx="7" ry="9" fill="#B07A4F"/><path d="M-8 -4 C-6 -12 6 -12 8 -4 Z" fill="#7A5A3A"/></g>';
  }

  static const hollies = ['#D9384F', '#F28C3C', '#B5304A'];
  static String holly(int v) {
    String leaf(num x, num y, num rot, String fill) => '<g transform="translate($x $y) rotate($rot)">'
        '<path d="M0 0 L6 -7 L10 -2 L16 -9 L20 -3 L27 -8 L30 0 L27 8 L20 3 L16 9 L10 2 L6 7 Z" fill="$fill"/></g>';
    final berry = hollies[v];
    return '${_stem('M100 172 C98 146 102 120 100 98', colour: '#5E4A3A', width: 4)}'
        '${leaf(100, 150, 200, '#2F6A4E')}${leaf(100, 132, -20, '#3F7A5A')}${leaf(100, 112, 210, '#3F7A5A')}${leaf(100, 104, -30, '#2F6A4E')}'
        '<circle cx="96" cy="96" r="6" fill="$berry"/><circle cx="106" cy="92" r="6" fill="$berry"/><circle cx="101" cy="86" r="6" fill="$berry"/>'
        '<ellipse cx="100" cy="74" rx="14" ry="5" fill="#FFFFFF" opacity="0.95"/>';
  }

  static String _darker(String hex) {
    final v = int.parse(hex.substring(1), radix: 16);
    String c(int x) => (x * 0.78).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${c(v >> 16 & 0xFF)}${c(v >> 8 & 0xFF)}${c(v & 0xFF)}';
  }
}
