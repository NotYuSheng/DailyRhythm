/// How a food was made this time: less sugar, no butter, extra rice. Each
/// built-in one moves the meal's calories and, through [DietScore]'s
/// "made lighter" and "made richer", its health. Anything else typed is
/// kept as a label and changes nothing.
class Modifier {
  const Modifier(this.key, this.label, this.kcal, {this.lighter = true});

  final String key;
  final String label;

  /// One serving's change in calories, roughly.
  final double kcal;

  /// Lighter (less oil, less sugar) or richer (extra cheese).
  final bool lighter;

  static const all = [
    Modifier('less_sugar', 'Less sugar', -20),
    Modifier('no_sugar', 'No sugar', -40),
    Modifier('less_oil', 'Less oil', -50),
    Modifier('no_butter', 'No butter', -35),
    Modifier('less_sauce', 'Less sauce', -30),
    Modifier('skin_off', 'Skin off', -60),
    Modifier('less_rice', 'Less rice', -100),
    Modifier('no_rice', 'No rice', -200),
    Modifier('extra_rice', 'Extra rice', 200, lighter: false),
    Modifier('extra_cheese', 'Extra cheese', 80, lighter: false),
    Modifier('extra_sauce', 'Extra sauce', 40, lighter: false),
  ];

  static Modifier? of(String key) => all.where((m) => m.key == key).firstOrNull;

  /// A modifier's label: a built-in's, or what was typed.
  static String labelOf(String mod) => of(mod)?.label ?? mod;

  /// One serving's change in calories from [mods].
  static double kcalChange(Iterable<String> mods) => mods.fold(0.0, (sum, m) => sum + (of(m)?.kcal ?? 0));

  /// The health categories [mods] add.
  static Set<String> tags(Iterable<String> mods) => {
    for (final m in mods)
      if (of(m) case final mod?) mod.lighter ? 'made_lighter' : 'made_richer',
  };
}
