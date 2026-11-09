import 'dart:math' as math;

import 'plant.dart';

/// The look of a period's garden scene: hills under a sky that follows
/// the season, golden hour for a whole year, and night in dark mode.
enum SceneLook {
  spring('Misty spring morning'),
  summer('Bright summer day'),
  autumn('Autumn hills'),
  winter('Snowy winter hills'),
  wholeYear('Golden hour'),
  night('Night hills');

  const SceneLook(this.label);

  final String label;

  /// Countries in the southern hemisphere's temperate belt, where October
  /// is spring. Everywhere else, tropics included, follows the northern
  /// calendar so the seasons still show.
  static const southernCountries = {'AU', 'NZ', 'AR', 'CL', 'UY', 'PY', 'ZA', 'LS', 'SZ', 'NA', 'BW', 'BR'};

  static bool southern(String? countryCode) => southernCountries.contains(countryCode?.toUpperCase());

  /// The season of [month] (1–12), meteorological: spring is March to May
  /// in the north, September to November in the south.
  static SceneLook forMonth(int month, {bool southern = false}) {
    final m = southern ? (month + 5) % 12 + 1 : month;
    return switch (m) {
      3 || 4 || 5 => spring,
      6 || 7 || 8 => summer,
      9 || 10 || 11 => autumn,
      _ => winter,
    };
  }

  /// The look for a period from [start] to [end]: its season when it fits
  /// in a season (a week or a month), golden hour when it's longer.
  static SceneLook forPeriod(DateTime start, DateTime end, {bool southern = false, bool dark = false}) {
    if (dark) return night;
    if (end.difference(start).inDays > 92) return wholeYear;
    final middle = start.add(Duration(days: end.difference(start).inDays ~/ 2));
    return forMonth(middle.month, southern: southern);
  }
}

class _Theme {
  const _Theme(this.sky, this.sun, this.ridges, this.shadow);

  final (String, String, String) sky;
  final (String, double, double, double) sun;
  final List<String> ridges;
  final String shadow;
}

const _themes = {
  SceneLook.spring: _Theme(('#CFE0F5', '#F6E3EE', '#FBF3EA'), ('#FFE7B8', 80, 96, 20), ['#D7DCEE', '#BFD8D4', '#A7CFC0', '#8FC4A9'], '#3A4A5A'),
  SceneLook.summer: _Theme(('#9FD3F2', '#CDEAF8', '#EEF8F2'), ('#FFF0A8', 270, 40, 18), ['#B8DCC4', '#9ED3B0', '#84C79C', '#6DBA88'], '#2B4A36'),
  SceneLook.autumn: _Theme(('#F8D9B0', '#FBEBD3', '#F6F1E6'), ('#FFCF8A', 230, 70, 20), ['#E8CDB5', '#D9C49A', '#C7B97E', '#A9B072'], '#5A3A2A'),
  SceneLook.winter: _Theme(('#D9E6F2', '#EDF2F8', '#F7FAFC'), ('#FFF4D6', 250, 60, 16), ['#DCE4EE', '#CCDDE0', '#B9D3CB', '#A5C9B6'], '#3A4A5A'),
  SceneLook.wholeYear: _Theme(('#F7C9B6', '#F3E0D2', '#EAF2EC'), ('#FFD9A0', 240, 78, 22), ['#D6CBE6', '#C2D9C8', '#A9CDB8', '#8CC3A0'], '#4A3A5A'),
  SceneLook.night: _Theme(('#1D2440', '#2B3456', '#3A4664'), ('#FFF1C4', 255, 50, 15), ['#3A4766', '#35585A', '#2F6450', '#2A6E4A'], '#000000'),
};

/// A period's plants on four ridges of hills: far ridges hold fewer,
/// smaller, hazier plants; each kind runs together along its ridge, tall
/// ones toward the middle; every plant stands on its hill's line with a
/// soft shadow. The same plants and seed always give the same picture.
class GardenScene {
  GardenScene._();

  static const width = 330.0;
  static const height = 230.0;

  /// The most plants drawn; more are sampled down in the same mix.
  static const maxPlants = 46;

  /// Up to [max] of [plants], keeping each kind's share (largest
  /// remainder), so a year of 300 plants reads like the year it was.
  static List<PlantSpecies> sample(List<PlantSpecies> plants, {int max = maxPlants}) {
    if (plants.length <= max) return plants;
    final counts = <PlantSpecies, int>{};
    for (final p in plants) {
      counts[p] = (counts[p] ?? 0) + 1;
    }
    final share = {for (final e in counts.entries) e.key: e.value * max / plants.length};
    final out = {for (final e in share.entries) e.key: e.value.floor()};
    final byRemainder = share.keys.toList()..sort((a, b) => (share[b]! - out[b]!).compareTo(share[a]! - out[a]!));
    for (final k in byRemainder.take(max - out.values.fold(0, (a, b) => a + b))) {
      out[k] = out[k]! + 1;
    }
    return [for (final e in out.entries) for (var i = 0; i < e.value; i++) e.key];
  }

  static String svg(List<PlantSpecies> plants, SceneLook look, {int seed = 0, PlantStyle style = PlantStyle.soft}) {
    final t = _themes[look]!;
    final rng = math.Random(seed);
    final shown = sample(plants);
    final big = shown.length <= 30;
    final b = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${_f(width)} ${_f(height)}">')
      ..write('<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">'
          '<stop offset="0" stop-color="${t.sky.$1}"/><stop offset="0.6" stop-color="${t.sky.$2}"/>'
          '<stop offset="1" stop-color="${t.sky.$3}"/></linearGradient></defs>')
      ..write('<rect width="$width" height="$height" fill="url(#sky)"/>');

    final (sunColor, sx, sy, sr) = t.sun;
    if (look == SceneLook.night) {
      for (var i = 0; i < 28; i++) {
        b.write('<circle cx="${_f(_range(rng, 10, 320))}" cy="${_f(_range(rng, 8, 100))}" r="${_f(_range(rng, 0.6, 1.5))}" '
            'fill="#FFFFFF" opacity="${_f(_range(rng, 0.4, 0.9))}"/>');
      }
      b.write('<circle cx="$sx" cy="$sy" r="$sr" fill="$sunColor"/><circle cx="${sx + 7}" cy="${sy - 5}" r="${sr - 2}" fill="#232B48"/>');
    } else {
      b.write('<circle cx="$sx" cy="$sy" r="${sr * 1.9}" fill="$sunColor" opacity="0.25"/><circle cx="$sx" cy="$sy" r="$sr" fill="$sunColor"/>');
    }
    switch (look) {
      case SceneLook.summer:
        b.write('<g fill="#FFFFFF" opacity="0.95"><ellipse cx="70" cy="40" rx="28" ry="10"/><ellipse cx="92" cy="34" rx="18" ry="9"/>'
            '<ellipse cx="190" cy="58" rx="22" ry="7"/></g>');
      case SceneLook.wholeYear:
        b.write('<path d="M60 46 q5 -5 10 0 q5 -5 10 0 M92 58 q4 -4 8 0 q4 -4 8 0 M120 40 q3 -3 6 0 q3 -3 6 0" '
            'fill="none" stroke="#7A5A6A" stroke-width="1.6" stroke-linecap="round"/>');
      default:
    }

    // Back ridges hold fewer plants; every ridge gets a mix of kinds.
    const weights = [0.14, 0.22, 0.3, 0.34];
    final per = [for (final w in weights) (shown.length * w).round()];
    per[3] = math.max(0, shown.length - per[0] - per[1] - per[2]);
    final pool = [...shown]..shuffle(rng);
    var k = 0;
    for (var i = 0; i < 4; i++) {
      final y = 96.0 + i * 34;
      final ridge = _Ridge(y, rng, 10.0 + i * 2);
      final depth = (i + 1) / 4;
      b.write('<path d="${ridge.path}" fill="${t.ridges[i]}"/>');
      if (look == SceneLook.winter) {
        b.write('<path d="${ridge.line}" fill="none" stroke="#FFFFFF" stroke-width="2.5" stroke-linecap="round" opacity="0.85"/>');
      }
      if (look == SceneLook.spring && i < 3) {
        b.write('<rect x="0" y="${_f(y + 4)}" width="$width" height="18" fill="#FFFFFF" opacity="0.35"/>');
      }
      // Kinds in runs along the ridge, the runs in a random order.
      final row = pool.sublist(k, math.min(pool.length, k + per[i]));
      k += row.length;
      final order = {for (final sp in row) sp: rng.nextDouble()};
      final arranged = row..sort((a, c) => order[a]!.compareTo(order[c]!));
      final placed = <(double, double, double, PlantSpecies, bool)>[];
      for (final (j, sp) in arranged.indexed) {
        final x = 18 + (j + 0.5) * 294 / arranged.length + _range(rng, -7, 7);
        // Far plants much smaller than near ones; tall kinds a little shorter.
        final s = (0.3 + 0.7 * depth) * (big ? 1.0 : 0.8) * 0.36 * (1 - _tallness(sp) * 0.025) * _range(rng, 0.9, 1.08);
        placed.add((ridge.at(x) + 2, x, s, sp, rng.nextDouble() < 0.4));
      }
      placed.sort((a, c) => a.$1.compareTo(c.$1));
      for (final (py, px, s, sp, flip) in placed) {
        final body = _body(PlantSvg.plant(PlantSpec(species: sp, logged: true), style: style));
        if (body == null) continue;
        b
          ..write('<ellipse cx="${_f(px)}" cy="${_f(py)}" rx="${_f(26 * s)}" ry="${_f(6 * s)}" fill="${t.shadow}" opacity="0.16"/>')
          ..write('<g transform="translate(${_f(px)} ${_f(py)}) scale(${_f3(flip ? -s : s)} ${_f3(s)}) translate(-100 -176)" '
              'opacity="${_f(0.72 + 0.28 * depth)}">$body</g>');
      }
    }

    switch (look) {
      case SceneLook.autumn:
        const leafColours = ['#E39B5A', '#D7713F', '#F0B657'];
        for (var i = 0; i < 10; i++) {
          b.write('<path d="M0 0 C3 -4 8 -4 10 0 C8 4 3 4 0 0 Z" fill="${leafColours[rng.nextInt(3)]}" '
              'transform="translate(${_f(_range(rng, 20, 310))} ${_f(_range(rng, 20, 150))}) rotate(${_f(_range(rng, 0, 360))})"/>');
        }
      case SceneLook.winter:
        for (var i = 0; i < 26; i++) {
          b.write('<circle cx="${_f(_range(rng, 6, 324))}" cy="${_f(_range(rng, 6, 200))}" r="${_f(_range(rng, 1, 2.2))}" fill="#FFFFFF" opacity="0.9"/>');
        }
      case SceneLook.night:
        for (var i = 0; i < 10; i++) {
          b.write('<circle cx="${_f(_range(rng, 30, 300))}" cy="${_f(_range(rng, 90, 200))}" r="2.2" fill="#FFF3A0" opacity="${_f(_range(rng, 0.4, 1))}"/>');
        }
      default:
    }
    b.write('</svg>');
    return b.toString();
  }

  /// How tall a kind grows, to put tall ones at the back and mid-ridge.
  static int _tallness(PlantSpecies s) => switch (s) {
        PlantSpecies.tree => 7,
        PlantSpecies.sunflower => 6,
        PlantSpecies.monstera => 5,
        PlantSpecies.cactus => 4,
        PlantSpecies.fern => 3,
        PlantSpecies.tulip => 2,
        PlantSpecies.sprout => 1,
        PlantSpecies.succulent => 0,
      };

  static String? _body(String? svg) {
    if (svg == null) return null;
    final start = svg.indexOf('>') + 1;
    final end = svg.lastIndexOf('</svg>');
    return start <= 0 || end < start ? null : svg.substring(start, end);
  }

  static double _range(math.Random r, double a, double b) => a + r.nextDouble() * (b - a);
  static String _f(num n) => n.toStringAsFixed(1);
  static String _f3(num n) => n.toStringAsFixed(3);
}

/// A smooth hill line across the scene: two curves, and the height of the
/// line at any x, so plants stand on it.
class _Ridge {
  _Ridge(double y, math.Random rng, double amp) {
    double r() => -amp + rng.nextDouble() * 2 * amp;
    final (a, b, c) = (r(), r(), r());
    _segments = [
      [(0.0, y), (70.0, y - amp * 0.9 + a), (150.0, y + b * 0.5), (215.0, y - amp * 0.6 + b)],
      [(215.0, y - amp * 0.6 + b), (260.0, y - amp * 1.1 + c), (300.0, y + c * 0.4), (330.0, y - amp * 0.4)],
    ];
    for (final s in _segments) {
      for (var t = 0; t <= 40; t++) {
        _points.add(_bezier(s, t / 40));
      }
    }
  }

  late final List<List<(double, double)>> _segments;
  final _points = <(double, double)>[];

  String get line {
    final s0 = _segments.first.first;
    final curves = [for (final s in _segments) 'C${_p(s[1])} ${_p(s[2])} ${_p(s[3])}'].join(' ');
    return 'M${_p(s0)} $curves';
  }

  String get path => '$line L330 230 L0 230 Z';

  double at(double x) => _points.reduce((a, b) => (a.$1 - x).abs() <= (b.$1 - x).abs() ? a : b).$2;

  static (double, double) _bezier(List<(double, double)> p, double t) {
    final u = 1 - t;
    double c(double a, double b, double cc, double d) => u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * cc + t * t * t * d;
    return (c(p[0].$1, p[1].$1, p[2].$1, p[3].$1), c(p[0].$2, p[1].$2, p[2].$2, p[3].$2));
  }

  static String _p((double, double) p) => '${p.$1.toStringAsFixed(1)} ${p.$2.toStringAsFixed(1)}';
}
