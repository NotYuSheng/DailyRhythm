import 'dart:math' as math;

import 'plant_ink.dart';
import 'seasonal_plants.dart';

export 'plant_ink.dart' show PlantStyle;
export 'seasonal_plants.dart' show Season, varietyCount, varietyOf;

/// What a day was mostly about, shown as the plant it grows.
enum PlantSpecies {
  sunflower('Exercise', 'sunflower', 'an exercise day'),
  succulent('Rest', 'succulent', 'a rest day'),
  tulip('People', 'tulip', 'time with people'),
  cactus('Work', 'cactus', 'a work day'),
  fern('Study', 'fern', 'a study day'),
  monstera('Games', 'monstera', 'games and videos'),
  tree('A big day', 'little tree', 'a big day out'),
  sprout('A bit of everything', 'sprout', 'a bit of everything');

  const PlantSpecies(this.label, this.plantName, this.dayWord);

  /// Button label for "today was mostly…".
  final String label;
  final String plantName;
  final String dayWord;

  String get pluralName => this == cactus ? 'cacti' : '${plantName}s';

  /// The plant this kind of day grows in [season]: the same family all
  /// year (work is always a cactus), a different member each season.
  String nameIn(Season season) => _seasonal[this]![season.index];

  String pluralIn(Season season) {
    final name = nameIn(season);
    return switch (name) {
      'cactus' => 'cacti',
      'Christmas cactus' => 'Christmas cacti',
      'barrel cactus' => 'barrel cacti',
      'cherry blossom' => 'cherry blossoms',
      'ivy' => 'ivies',
      'rosemary' => 'rosemary',
      'holly sprig' => 'holly sprigs',
      'snowy pine' => 'snowy pines',
      _ => '${name}s',
    };
  }

  static PlantSpecies? byName(String? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// Spring, summer, autumn and winter plants for each kind of day.
const _seasonal = {
  PlantSpecies.sunflower: ['daffodil', 'sunflower', 'chrysanthemum', 'snowdrop'],
  PlantSpecies.succulent: ['echeveria', 'succulent', 'sedum', 'jade plant'],
  PlantSpecies.tulip: ['tulip', 'hibiscus', 'aster', 'poinsettia'],
  PlantSpecies.cactus: ['barrel cactus', 'cactus', 'prickly pear', 'Christmas cactus'],
  PlantSpecies.fern: ['fiddlehead fern', 'fern', 'rosemary', 'ivy'],
  PlantSpecies.monstera: ['calathea', 'monstera', 'croton', 'snake plant'],
  PlantSpecies.tree: ['cherry blossom', 'little tree', 'maple', 'snowy pine'],
  PlantSpecies.sprout: ['seedling', 'sprout', 'oak seedling', 'holly sprig'],
};

/// One day's plant. It says only what kind of day it was (its family) and
/// when (the season picks the family member); the variety only keeps
/// neighbouring days from looking alike. The numbers live in Metrics.
class PlantSpec {
  const PlantSpec({required this.species, this.logged = true, this.season = Season.summer, this.variety = 0});

  /// The plant a kind of day grows on [day]: its season's plant, in the
  /// variety that day's place in the year picks.
  factory PlantSpec.on(DateTime day, {required PlantSpecies species, bool logged = true}) =>
      PlantSpec(species: species, logged: logged, season: Season.of(day), variety: varietyOf(day));

  final PlantSpecies species;

  /// False draws an empty pot.
  final bool logged;
  final Season season;

  /// 0 to [varietyCount] − 1.
  final int variety;

  String get name => species.nameIn(season);

  /// "a cactus", "an oak seedling".
  String get aName => '${RegExp('^[aeiou]', caseSensitive: false).hasMatch(name) ? 'an' : 'a'} $name';

  @override
  bool operator ==(Object other) =>
      other is PlantSpec && other.species == species && other.logged == logged && other.season == season && other.variety == variety;

  @override
  int get hashCode => Object.hash(species, logged, season, variety);

  String get semanticLabel => logged ? '${_capital(aName)}: ${species.dayWord}' : 'Empty pot: nothing logged that day';
}

String _capital(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

const potColors = ['#F2A27E', '#B7A8F2', '#8CC8FF', '#9FDCB9'];
const _potShades = {'#F2A27E': '#E08A64', '#B7A8F2': '#9C8BE6', '#8CC8FF': '#6FB2EE', '#9FDCB9': '#83CBA2'};

/// SVG for a plant in a 200×240 box, as two layers so the plant can sway
/// above a still pot. Ported from the garden prototype.
class PlantSvg {
  PlantSvg._();

  static const width = 200.0;
  static const height = 240.0;

  /// Where the stem meets the soil, as a fraction of the box (sway pivot).
  static const pivotY = 176 / height;

  static String _wrap(String body) =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 240">$body</svg>';

  static String _f(num n) => n.toStringAsFixed(1);

  static String pot(String color, {PlantStyle style = PlantStyle.soft}) =>
      style == PlantStyle.ink ? PlantInk.inked(_pot(color)) : _pot(color);

  static String _pot(String color) {
    final rim = _potShades[color] ?? color;
    return _wrap(
      '<ellipse cx="100" cy="236" rx="56" ry="4" fill="#2B2440" opacity="0.08"/>'
      '<path d="M52 182 L148 182 L138 230 C137 234 134 236 130 236 L70 236 C66 236 63 234 62 230 Z" fill="$color"/>'
      '<path d="M60 190 L66 226" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" opacity="0.35"/>'
      '<rect x="46" y="172" width="108" height="16" rx="8" fill="$rim"/>'
      '<ellipse cx="100" cy="176" rx="46" ry="5" fill="#7A513D"/>',
    );
  }

  /// Leaves, arms and fronds every plant grows: the same for each day, so
  /// a plant's look is its species and nothing else.
  static const _growth = 3;
  static const _scale = 0.88;

  /// The plant itself, or null for an empty pot.
  static String? plant(PlantSpec spec, {PlantStyle style = PlantStyle.soft}) {
    final soft = _plant(spec);
    return soft == null || style == PlantStyle.soft ? soft : PlantInk.inked(soft);
  }

  static String? _plant(PlantSpec spec) {
    if (!spec.logged) return null;
    // People: tulips in spring, hibiscus in summer.
    final seasonal = spec.season != Season.summer || spec.species == PlantSpecies.tulip;
    if (seasonal) {
      final v = spec.variety % varietyCount;
      final art = switch ((spec.species, spec.season)) {
        (PlantSpecies.sunflower, Season.spring) => SeasonalArt.daffodil(v),
        (PlantSpecies.sunflower, Season.autumn) => SeasonalArt.chrysanthemum(v),
        (PlantSpecies.sunflower, _) => SeasonalArt.snowdrop(v),
        (PlantSpecies.succulent, Season.spring) => SeasonalArt.echeveria(v),
        (PlantSpecies.succulent, Season.autumn) => SeasonalArt.sedum(v),
        (PlantSpecies.succulent, _) => SeasonalArt.jade(v),
        (PlantSpecies.tulip, Season.spring) => _summerArt(PlantSpecies.tulip, v),
        (PlantSpecies.tulip, Season.summer) => SeasonalArt.hibiscus(v),
        (PlantSpecies.tulip, Season.autumn) => SeasonalArt.aster(v),
        (PlantSpecies.tulip, _) => SeasonalArt.poinsettia(v),
        (PlantSpecies.cactus, Season.spring) => SeasonalArt.barrel(v),
        (PlantSpecies.cactus, Season.autumn) => SeasonalArt.pricklyPear(v),
        (PlantSpecies.cactus, _) => SeasonalArt.christmasCactus(v),
        (PlantSpecies.fern, Season.spring) => SeasonalArt.fiddlehead(v),
        (PlantSpecies.fern, Season.autumn) => SeasonalArt.rosemary(v),
        (PlantSpecies.fern, _) => SeasonalArt.ivy(v),
        (PlantSpecies.monstera, Season.spring) => SeasonalArt.calathea(v),
        (PlantSpecies.monstera, Season.autumn) => SeasonalArt.croton(v),
        (PlantSpecies.monstera, _) => SeasonalArt.snakePlant(v),
        (PlantSpecies.tree, Season.spring) => SeasonalArt.cherry(v),
        (PlantSpecies.tree, Season.autumn) => SeasonalArt.maple(v),
        (PlantSpecies.tree, _) => SeasonalArt.pine(v),
        (PlantSpecies.sprout, Season.spring) => SeasonalArt.seedling(v),
        (PlantSpecies.sprout, Season.autumn) => SeasonalArt.oak(v),
        (PlantSpecies.sprout, _) => SeasonalArt.holly(v),
      };
      return _wrap('<g transform="translate(100 176) scale(${_scale.toStringAsFixed(2)}) translate(-100 -176)">$art</g>');
    }
    return _wrap(_summerArt(spec.species, spec.variety % varietyCount, scaled: true));
  }

  /// Bloom colours for the summer plants' varieties.
  static const _summerVarieties = {
    PlantSpecies.sunflower: [<String, String>{}, {'#FFC93C': '#F49A3C'}, {'#FFC93C': '#D9534F', '#8A5A35': '#4A2E1E'}],
    PlantSpecies.tulip: [<String, String>{}, {'#FF7A8A': '#B7A0E8', '#FFA3AE': '#D6C8F4'}, {'#FF7A8A': '#FFC93C', '#FFA3AE': '#FFE08A'}],
    PlantSpecies.succulent: [<String, String>{}, {'#FF9EB5': '#FFD27A', '#F2A7BE': '#F7C26B'}, {'#7CC4A0': '#A9C8E8', '#A8DDBF': '#C3D8EE'}],
    PlantSpecies.cactus: [<String, String>{}, {'#FF9EB5': '#FFD45C'}, {'#FF9EB5': '#F07B6A'}],
    PlantSpecies.fern: [<String, String>{}, {'#E5484D': '#FFC93C'}, {'#5BB884': '#7FB57A', '#7CCB9A': '#9FD08A'}],
    PlantSpecies.monstera: [<String, String>{}, {'#FFF3D6': '#FFFFFF', '#F2D27E': '#F7B733'}, {'#3F9E6A': '#2F7F5A', '#4FAE78': '#3F9E6A'}],
    PlantSpecies.tree: [<String, String>{}, {'#FFB3C7': '#F07B6A'}, {'#FFB3C7': '#FFFFFF', '#5BB884': '#6FB5A5'}],
    PlantSpecies.sprout: [<String, String>{}, {'#FF9EB5': '#FFD45C'}, {'#FF9EB5': '#B7A0E8'}],
  };

  static String _summerArt(PlantSpecies species, int variety, {bool scaled = false}) {
    var art = _summerBody(species);
    for (final MapEntry(:key, :value) in _summerVarieties[species]![variety].entries) {
      art = art.replaceAll(key, value);
    }
    return scaled ? '<g transform="translate(100 176) scale(${_scale.toStringAsFixed(2)}) translate(-100 -176)">$art</g>' : art;
  }

  static String _summerBody(PlantSpecies species) {
    final spec = PlantSpec(species: species);
    const move = _growth;
    final b = StringBuffer();
    const greens = ['#5BB884', '#7CCB9A'];

    switch (spec.species) {
      case PlantSpecies.sprout:
        b.write('<path d="M100 172 C96 140 104 110 100 76" fill="none" stroke="#3F9E6A" stroke-width="6" stroke-linecap="round"/>');
        final n = math.max(1, move);
        for (var i = 0; i < n; i++) {
          final y = 156 - i * (64 / n);
          final left = i.isEven;
          b.write('<path d="M0 0 C10 -12 30 -12 40 0 C30 10 10 10 0 0 Z" fill="${greens[i % 2]}" '
              'transform="translate(100 ${_f(y)}) rotate(${left ? 200 : -20})"/>');
        }
      case PlantSpecies.succulent:
        final n = 5 + move;
        for (var j = 0; j < n; j++) {
          final a = -78 + j * (156 / (n - 1));
          b.write('<g transform="rotate(${_f(a)} 100 166)">'
              '<path d="M100 166 C86 150 88 118 100 104 C112 118 114 150 100 166 Z" fill="#7CC4A0"/>'
              '<path d="M100 104 C96 109 95 113 96 116 C99 113 101 113 104 116 C105 113 104 109 100 104 Z" fill="#F2A7BE"/>'
              '</g>');
        }
        for (final a in [-36, -18, 0, 18, 36]) {
          b.write('<path d="M100 162 C91 152 92 132 100 122 C108 132 109 152 100 162 Z" fill="#A8DDBF" transform="rotate($a 100 162)"/>');
        }
        b.write('<ellipse cx="100" cy="156" rx="8" ry="6" fill="#CDEEDB"/>');
      case PlantSpecies.cactus:
        if (move >= 1) {
          b.write('<path d="M82 132 H70 C62 132 58 126 58 118 V100" fill="none" stroke="#5DBB7E" stroke-width="18" stroke-linecap="round" stroke-linejoin="round"/>');
        }
        if (move >= 3) {
          b.write('<path d="M118 112 H130 C138 112 142 106 142 98 V84" fill="none" stroke="#5DBB7E" stroke-width="18" stroke-linecap="round" stroke-linejoin="round"/>');
        }
        b.write('<rect x="78" y="62" width="44" height="114" rx="22" fill="#5DBB7E"/>'
            '<path d="M93 72 V168 M107 72 V168" stroke="#86D3A2" stroke-width="3" stroke-linecap="round" opacity="0.8"/>');
        for (final p in const [[86, 80], [114, 92], [86, 108], [114, 124], [86, 140], [114, 152], [100, 74], [100, 160]]) {
          b.write('<path d="M${p[0]} ${p[1]} l-4 -3 M${p[0]} ${p[1]} l4 -3" stroke="#F1F8EC" stroke-width="2" stroke-linecap="round"/>');
        }
      case PlantSpecies.tulip:
        b.write('<path d="M100 172 C98 140 102 112 100 88" fill="none" stroke="#3F9E6A" stroke-width="5" stroke-linecap="round"/>'
            '<path d="M100 170 C74 152 68 120 78 96 C86 122 92 146 100 160 Z" fill="#5BB884"/>');
        if (move >= 1) b.write('<path d="M100 170 C126 152 132 126 124 106 C116 128 108 148 100 160 Z" fill="#7CCB9A"/>');
        if (move >= 3) b.write('<path d="M100 150 C86 138 84 122 88 110 C94 124 98 136 102 144 Z" fill="#8FD6A9"/>');
      case PlantSpecies.sunflower:
        b.write('<path d="M100 172 C96 132 104 92 100 60" fill="none" stroke="#3F9E6A" stroke-width="6" stroke-linecap="round"/>');
        final n = math.max(1, move);
        for (var s = 0; s < n; s++) {
          final y = 150 - s * (70 / n);
          final left = s.isEven;
          b.write('<path d="M0 0 C8 -16 32 -18 42 -4 C32 12 10 12 0 0 Z" fill="${greens[s % 2]}" '
              'transform="translate(${left ? 98 : 102} ${_f(y)}) rotate(${left ? 205 : -25})"/>');
        }
      case PlantSpecies.fern:
        final n = 3 + move;
        final leaflets = StringBuffer();
        for (var f = 0; f < n; f++) {
          final ang = (-62 + f * (124 / (n - 1))) * math.pi / 180;
          const len = 104.0;
          const p0 = (100.0, 172.0);
          final c = (100 + math.sin(ang) * len * 0.25, 172 - math.cos(ang) * len * 1.05);
          final t1 = (100 + math.sin(ang) * len * 0.95, 172 - math.cos(ang) * len * 0.55);
          b.write('<path d="M${p0.$1} ${p0.$2} Q${_f(c.$1)} ${_f(c.$2)} ${_f(t1.$1)} ${_f(t1.$2)}" fill="none" stroke="#3F9E6A" stroke-width="3" stroke-linecap="round"/>');
          for (var t = 0.22; t <= 0.96; t += 0.1) {
            final bx = (1 - t) * (1 - t) * p0.$1 + 2 * (1 - t) * t * c.$1 + t * t * t1.$1;
            final by = (1 - t) * (1 - t) * p0.$2 + 2 * (1 - t) * t * c.$2 + t * t * t1.$2;
            final dx = 2 * (1 - t) * (c.$1 - p0.$1) + 2 * t * (t1.$1 - c.$1);
            final dy = 2 * (1 - t) * (c.$2 - p0.$2) + 2 * t * (t1.$2 - c.$2);
            final th = math.atan2(dy, dx) * 180 / math.pi;
            final l = math.sqrt(dx * dx + dy * dy);
            final nx = -dy / l, ny = dx / l;
            final rx = 8.5 * (1 - t * 0.55);
            for (final side in const [1, -1]) {
              final cx = bx + nx * side * (rx * 0.8), cy = by + ny * side * (rx * 0.8);
              leaflets.write('<ellipse cx="${_f(cx)}" cy="${_f(cy)}" rx="${_f(rx)}" ry="3.6" '
                  'fill="${side > 0 ? '#5BB884' : '#7CCB9A'}" transform="rotate(${_f(th + side * 55)} ${_f(cx)} ${_f(cy)})"/>');
            }
          }
        }
        b.write(leaflets);
      case PlantSpecies.monstera:
        const spots = [[-38, 74, 70], [30, 86, 92], [-8, 64, 52], [48, 108, 112]];
        final n = 2 + move ~/ 2;
        for (var m = 0; m < n; m++) {
          final sp = spots[m];
          final ex = 100 + sp[0], ey = sp[1];
          b.write('<path d="M100 172 Q${_f(100 + sp[0] * 0.2)} ${sp[2] + 30} $ex ${ey + 22}" fill="none" stroke="#3F9E6A" stroke-width="4" stroke-linecap="round"/>'
              '<g transform="translate($ex $ey) rotate(${(sp[0] * 0.6).round()}) scale(${m == 2 ? 0.8 : 1})">'
              '<path d="M0 28 C-32 16 -36 -18 -15 -30 C-6 -34 0 -27 0 -21 C0 -27 6 -34 15 -30 C36 -18 32 16 0 28 Z" fill="${m.isOdd ? '#4FAE78' : '#3F9E6A'}"/>'
              '<path d="M0 24 V-18 M0 6 L-22 -6 M0 6 L22 -6 M0 -6 L-18 -20 M0 -6 L18 -20" stroke="#E9F6EE" stroke-width="2.4" stroke-linecap="round" opacity="0.75"/>'
              '</g>');
        }
      case PlantSpecies.tree:
        b.write('<path d="M100 172 C98 150 104 132 96 108 M98 138 C110 130 118 124 124 112" fill="none" stroke="#8A5E48" stroke-width="9" stroke-linecap="round"/>');
        const clouds = [[98, 96, 30], [122, 104, 24], [76, 108, 24], [110, 76, 22], [84, 82, 20]];
        for (var c = 0; c < math.min(5, 2 + move); c++) {
          final cs = clouds[c];
          b.write('<circle cx="${cs[0]}" cy="${cs[1]}" r="${cs[2]}" fill="${c.isOdd ? '#7CCB9A' : '#5BB884'}"/>');
        }
    }

    final top = _tops[spec.species]!;
    b.write('<g transform="translate(${top.$1} ${top.$2})">${_bloom(spec.species)}</g>');
    return b.toString();
  }

  static const _tops = {
    PlantSpecies.sprout: (100, 70),
    PlantSpecies.succulent: (122, 96),
    PlantSpecies.cactus: (100, 60),
    PlantSpecies.tulip: (100, 86),
    PlantSpecies.sunflower: (100, 52),
    PlantSpecies.fern: (130, 112),
    PlantSpecies.monstera: (86, 150),
    PlantSpecies.tree: (100, 92),
  };

  static String _petals(int n, num r, num rx, num ry, String fill) => [
        for (var k = 0; k < n; k++)
          '<ellipse cx="0" cy="${-r}" rx="$rx" ry="$ry" fill="$fill" transform="rotate(${_f(k * 360 / n)})"/>',
      ].join();

  static String _bloom(PlantSpecies species) {
    switch (species) {
      case PlantSpecies.sunflower:
        return '${_petals(14, 16, 5.5, 11, '#FFC93C')}<circle cx="0" cy="0" r="12" fill="#8A5A35"/>'
            '<circle cx="-4" cy="-3" r="1.6" fill="#B07A4F"/><circle cx="4" cy="-2" r="1.6" fill="#B07A4F"/><circle cx="0" cy="4" r="1.6" fill="#B07A4F"/>';
      case PlantSpecies.tulip:
        return '<path d="M-16 -6 C-16 16 16 16 16 -6 C12 0 8 -6 0 -14 C-8 -6 -12 0 -16 -6 Z" fill="#FF7A8A"/>'
            '<path d="M-8 -10 C-4 -16 4 -16 8 -10 C4 -4 -4 -4 -8 -10 Z" fill="#FFA3AE"/>';
      case PlantSpecies.fern:
        return '<circle cx="0" cy="0" r="8" fill="#E5484D"/><path d="M0 -8 V8" stroke="#2B2440" stroke-width="1.6"/>'
            '<circle cx="0" cy="-8" r="4" fill="#2B2440"/><circle cx="-3.5" cy="1" r="1.8" fill="#2B2440"/><circle cx="3.5" cy="3" r="1.8" fill="#2B2440"/>';
      case PlantSpecies.monstera:
        return '<path d="M0 10 C-12 -2 -9 -22 0 -30 C9 -22 12 -2 0 10 Z" fill="#FFF3D6"/>'
            '<path d="M0 4 V-18" stroke="#F2D27E" stroke-width="4" stroke-linecap="round"/>';
      case PlantSpecies.tree:
        return [
          for (final p in const [[-20, -4], [14, -12], [2, 10], [24, 12], [-10, -24], [-26, 16]])
            '<circle cx="${p[0]}" cy="${p[1]}" r="4.2" fill="#FFB3C7"/>',
        ].join();
      case PlantSpecies.succulent:
        return '${_petals(5, 6, 4, 6, '#FF9EB5')}<circle cx="0" cy="0" r="3.5" fill="#FFD27A"/>';
      case PlantSpecies.cactus:
      case PlantSpecies.sprout:
        return '${_petals(5, 11, 9, 10, '#FF9EB5')}<circle cx="0" cy="0" r="7" fill="#FFD27A"/>';
    }
  }
}
