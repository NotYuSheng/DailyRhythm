/// How big a meal was against the food's usual serving, for its calories.
enum Portion {
  small('Small', 0.7),
  regular('Regular', 1),
  large('Large', 1.4);

  const Portion(this.label, this.factor);

  final String label;

  /// Calories against a regular serving.
  final double factor;
}
