/// Quick daily ratings relative to a usual day, from -2 (much lower) to
/// +2 (much higher), plus the garden's "today was mostly…" plant choice.
class DayCheckin {
  static const int min = -2;
  static const int max = 2;

  final DateTime date;
  final int? energy;
  final int? stress;
  final int? focus;
  final String? plantOverride;

  DayCheckin({required this.date, this.energy, this.stress, this.focus, this.plantOverride}) {
    for (final value in [energy, stress, focus]) {
      if (value != null && (value < min || value > max)) {
        throw RangeError.range(value, min, max, 'rating');
      }
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'energy': energy,
      'stress': stress,
      'focus': focus,
      'plant_override': plantOverride,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory DayCheckin.fromMap(Map<String, dynamic> map) {
    return DayCheckin(
      date: DateTime.parse(map['date'] as String),
      energy: map['energy'] as int?,
      stress: map['stress'] as int?,
      focus: map['focus'] as int?,
      plantOverride: map['plant_override'] as String?,
    );
  }
}
