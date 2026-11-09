import 'package:material_ui/material_ui.dart';

import '../data/models/tag.dart';

/// An outline icon for a tag. Icons are drawn in the text colour of
/// whatever shows the tag, never in their own colours, so they sit in the
/// garden palette in light and dark mode.
///
/// Matched on the tag's name first (imported tags carry an icon name from
/// another app that doesn't always fit, e.g. a cab drawn as a house), then
/// on that stored icon name, then by kind.
IconData tagIcon(Tag tag) {
  final name = tag.name.toLowerCase();
  for (final (pattern, icon) in _byName) {
    if (pattern.hasMatch(name)) return icon;
  }
  return _byStoredIcon[tag.emoji] ??
      switch (tag.knownKind) {
        TagKind.foodSource => Icons.restaurant_outlined,
        TagKind.symptom => Icons.healing_outlined,
        _ => Icons.local_activity_outlined,
      };
}

final _byName = <(RegExp, IconData)>[
  // Activities
  (RegExp(r'\b(cab|taxi|grab|uber)\b'), Icons.local_taxi_outlined),
  (RegExp(r'bed ?sheets?'), Icons.bed_outlined),
  (RegExp(r'\b(class|lecture|school)\b'), Icons.school_outlined),
  (RegExp(r'dentist|tooth'), Icons.medical_services_outlined),
  (RegExp(r'\b(draw|paint|art)'), Icons.brush_outlined),
  (RegExp(r'exercise|gym|workout|run\b'), Icons.fitness_center),
  (RegExp(r'family issues?|argument|conflict'), Icons.report_outlined),
  (RegExp(r'family'), Icons.family_restroom),
  (RegExp(r'hair ?cut'), Icons.content_cut),
  (RegExp(r'\bnap\b'), Icons.hotel_outlined),
  (RegExp(r'slept early|sleep'), Icons.bedtime_outlined),
  (RegExp(r'social|party|friends|date\b'), Icons.groups_outlined),
  (RegExp(r'stud(y|ying)|read'), Icons.menu_book_outlined),
  (RegExp(r'\b(test|exam|quiz)\b'), Icons.quiz_outlined),
  (RegExp(r'gam(e|es|ing)'), Icons.sports_esports_outlined),
  (RegExp(r'video|movie|tv\b|youtube|watch'), Icons.smart_display_outlined),
  (RegExp(r'woke up early|early start'), Icons.wb_twilight_outlined),
  (RegExp(r'\bwork'), Icons.work_outline),
  // Where food came from
  (RegExp(r'delivery'), Icons.delivery_dining_outlined),
  (RegExp(r'fast ?food'), Icons.fastfood_outlined),
  (RegExp(r'food court|hawker'), Icons.storefront_outlined),
  (RegExp(r'free food'), Icons.card_giftcard_outlined),
  (RegExp(r'home ?made|cooked'), Icons.soup_kitchen_outlined),
  (RegExp(r'restaurant|cafe'), Icons.restaurant_outlined),
  (RegExp(r'supplement|vitamin'), Icons.medication_outlined),
  (RegExp(r'take ?out|takeaway'), Icons.takeout_dining_outlined),
  // Symptoms
  (RegExp(r'anxi|stress|worr'), Icons.sentiment_dissatisfied_outlined),
  (RegExp(r'back pain|neck pain|muscle'), Icons.personal_injury_outlined),
  (RegExp(r'congestion|runny nose|sneez'), Icons.air),
  (RegExp(r'cough|flu|covid'), Icons.coronavirus_outlined),
  (RegExp(r'drows|tired|fatigue'), Icons.bedtime_outlined),
  (RegExp(r'fever|temperature'), Icons.thermostat_outlined),
  (RegExp(r'head ?ache|migraine'), Icons.psychology_outlined),
  (RegExp(r'rash|itch|skin'), Icons.healing_outlined),
  (RegExp(r'throat'), Icons.record_voice_over_outlined),
  (RegExp(r'stomach|gastric|nausea|diarr|constipat'), Icons.sick_outlined),
];

/// Icon names stored on imported tags, for tags whose name says nothing.
const _byStoredIcon = <String, IconData>{
  'home': Icons.home_outlined,
  'bed': Icons.bed_outlined,
  'graduation_cap': Icons.school_outlined,
  'clinic_medical': Icons.medical_services_outlined,
  'brush_alt': Icons.brush_outlined,
  'dumbbell': Icons.fitness_center,
  'exclamation_triangle': Icons.report_outlined,
  'scissors': Icons.content_cut,
  'moon': Icons.bedtime_outlined,
  'glass_martini': Icons.local_bar_outlined,
  'book': Icons.menu_book_outlined,
  'file_alt': Icons.description_outlined,
  'game_structure': Icons.sports_esports_outlined,
  'play_circle': Icons.play_circle_outline,
  'arrow_up': Icons.north,
  'briefcase': Icons.work_outline,
  'sad': Icons.sentiment_dissatisfied_outlined,
  'temperature': Icons.thermostat_outlined,
  'hospital': Icons.local_hospital_outlined,
  'sick': Icons.sick_outlined,
  'tear': Icons.water_drop_outlined,
};
